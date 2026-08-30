from __future__ import annotations

import json
import logging

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.confidence import should_escalate
from core.config import get_settings
from core.enrichment import EnrichmentRejected, parse_draft, validate_enrichment
from core.llm import LlmError, complete_structured
from core.models import Event, EventChunk, EventEnrichment, IngestRun, Organizer, Series, WebDocument

log = logging.getLogger(__name__)

ENRICH_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "true_format",
        "format_confidence",
        "level",
        "hands_on",
        "expect",
        "who_should_come",
        "prep_needed",
        "watch_outs",
        "evidence",
    ],
    "properties": {
        "true_format": {
            "type": "string",
            "enum": [
                "workshop",
                "talk",
                "panel",
                "networking",
                "hackathon",
                "demo_day",
                "social",
                "conference",
                "unclear",
            ],
        },
        "format_confidence": {"type": "number"},
        "level": {
            "type": "string",
            "enum": ["beginner", "intermediate", "advanced", "mixed", "unclear"],
        },
        "hands_on": {"type": "boolean"},
        "expect": {"type": "string"},
        "who_should_come": {"type": "array", "items": {"type": "string"}},
        "prep_needed": {"type": ["string", "null"]},
        "watch_outs": {"type": "array", "items": {"type": "string"}},
        "evidence": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["claim", "source_url", "source_title", "quote"],
                "properties": {
                    "claim": {"type": "string"},
                    "source_url": {"type": "string"},
                    "source_title": {"type": "string"},
                    "quote": {"type": "string"},
                },
            },
        },
    },
}


def enrich_pending(session: Session, run: IngestRun | None = None) -> int:
    events = session.scalars(
        select(Event).where(
            Event.id.notin_(select(EventEnrichment.event_id)),
            Event.status == "upcoming",
        )
    ).all()
    count = 0
    for event in events:
        if enrich_event(session, event, run, retry=True):
            count += 1
            if run:
                run.events_enriched = (run.events_enriched or 0) + 1
    return count


def enrich_event(session: Session, event: Event, run: IngestRun | None = None, retry: bool = True) -> bool:
    try:
        return _enrich_once(session, event)
    except EnrichmentRejected as exc:
        _log_run_error(run, f"enrichment rejected for {event.id}: {exc}")
        if retry:
            try:
                # Retry with the rejection reason. The previous implementation
                # re-sent an identical prompt, so a model that paraphrased a
                # quote simply paraphrased it again - half the verdicts were
                # lost to a retry that could not learn anything.
                return _enrich_once(session, event, correction=str(exc))
            except (EnrichmentRejected, LlmError) as retry_exc:
                _log_run_error(run, f"enrichment retry failed for {event.id}: {retry_exc}")
                return False
        return False
    except LlmError as exc:
        _log_run_error(run, f"enrichment LLM down for {event.id}: {exc}")
        return False


def _enrich_once(session: Session, event: Event, correction: str | None = None) -> bool:
    # Idempotence guard. Enrichment is expensive and the caller may retry after
    # an unrelated failure, so inserting blindly risks a unique violation on
    # event_id that aborts the whole transaction - taking unrelated work with it.
    if session.get(EventEnrichment, event.id) is not None:
        log.info("event %s already has a verdict; skipping", event.id)
        return False

    chunks = session.scalars(select(EventChunk).where(EventChunk.event_id == event.id)).all()
    docs = []
    urls = {chunk.source_url for chunk in chunks if chunk.source_url}
    if urls:
        docs = session.scalars(select(WebDocument).where(WebDocument.url.in_(urls))).all()

    allowed_urls = {url for url in urls}
    source_texts: dict[str, str] = {}
    for chunk in chunks:
        if chunk.source_url:
            source_texts[chunk.source_url] = (source_texts.get(chunk.source_url) or "") + " " + chunk.content
    for doc in docs:
        source_texts[doc.url] = doc.content
        allowed_urls.add(doc.url)
    if event.url:
        allowed_urls.add(event.url)
        source_texts.setdefault(event.url, event.description_raw or event.title)

    series = session.get(Series, event.series_id) if event.series_id else None
    organizer = session.get(Organizer, event.organizer_id) if event.organizer_id else None
    past = []
    if event.series_id:
        past = session.scalars(
            select(Event).where(Event.series_id == event.series_id, Event.id != event.id).limit(8)
        ).all()

    user = json.dumps(
        {
            "event": {
                "title": event.title,
                "url": event.url,
                "description": event.description_raw,
                "venue": event.venue_name,
            },
            "organizer": {"name": organizer.name, "summary": organizer.profile_summary} if organizer else None,
            "series": {"title": series.canonical_title, "verdict": series.format_verdict} if series else None,
            "past_editions": [{"title": item.title, "url": item.url} for item in past],
            "chunks": [
                {"source_url": chunk.source_url, "content": chunk.content[:1500]}
                for chunk in chunks[:12]
            ],
        }
    )

    if correction:
        user = json.dumps(
            {
                "previous_attempt_was_rejected": correction,
                "instruction": (
                    "Your last answer was discarded. Copy every quote "
                    "character-for-character from the source text below - no "
                    "paraphrasing, no ellipsis, no tidying. Prefer a short "
                    "contiguous run you can copy exactly."
                ),
                **json.loads(user),
            }
        )

    settings = get_settings()
    result = complete_structured(
        prompt_name="enrich.md",
        model=settings.openai_model_enrich,
        user=user,
        schema=ENRICH_SCHEMA,
        schema_name="event_enrichment",
    )
    draft = validate_enrichment(parse_draft(result.content), allowed_urls, source_texts)
    row = EventEnrichment(
        event_id=event.id,
        true_format=draft.true_format,
        format_confidence=draft.format_confidence,
        level=draft.level,
        hands_on=draft.hands_on,
        expect=draft.expect,
        who_should_come=draft.who_should_come,
        prep_needed=draft.prep_needed,
        watch_outs=draft.watch_outs,
        evidence=[item.__dict__ for item in draft.evidence],
        escalated=should_escalate(draft.format_confidence),
        model=result.model,
        prompt_version=result.prompt_version,
        tokens_in=result.tokens_in,
        tokens_out=result.tokens_out,
    )
    # Savepoint so a losing race writes nothing rather than poisoning the
    # surrounding transaction.
    try:
        with session.begin_nested():
            session.add(row)
            session.flush()
    except IntegrityError:
        log.info("verdict for %s was written concurrently; keeping the existing one", event.id)
        return False
    return True


def _log_run_error(run: IngestRun | None, message: str) -> None:
    log.warning(message)
    if run is None:
        return
    errors = list(run.errors or [])
    errors.append(message)
    run.errors = errors
