from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from core.config import get_settings
from core.embeddings import cosine_distance, embed_one
from core.llm import LlmError, complete_structured
from core.models import Event, Series
from core.title_normalize import normalize_title
from worker.series_match import LOW_COSINE, LOW_TRIGRAM, SeriesCandidate, decide_match

log = logging.getLogger(__name__)

MATCH_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["same_series", "reason"],
    "properties": {
        "same_series": {"type": "boolean"},
        "reason": {"type": "string"},
    },
}


def resolve_unlinked(session: Session) -> int:
    events = session.scalars(select(Event).where(Event.series_id.is_(None))).all()
    resolved = 0
    for event in events:
        if resolve_event(session, event):
            resolved += 1
    return resolved


def resolve_event(session: Session, event: Event) -> bool:
    key = normalize_title(event.title)
    if not key:
        return False
    candidates = _candidates(session, event, key)
    decision = decide_match(candidates)

    if decision == "new":
        _create_series(session, event, key)
        return True
    if decision.startswith("match:"):
        series_id = decision.split(":", 1)[1]
        event.series_id = series_id
        return True

    matched = _llm_tiebreak(event, key, candidates)
    if matched:
        event.series_id = matched
        return True
    _create_series(session, event, key)
    return True


def _candidates(session: Session, event: Event, key: str) -> list[SeriesCandidate]:
    if not event.organizer_id:
        rows = session.scalars(select(Series).where(Series.normalized_key == key)).all()
        return [
            SeriesCandidate(str(row.id), row.canonical_title, row.normalized_key, 1.0, 0.0)
            for row in rows
        ]

    try:
        rows = session.execute(
            text(
                """
                SELECT id::text, canonical_title, normalized_key,
                       similarity(normalized_key, :key) AS trigram
                FROM series
                WHERE organizer_id = :organizer_id
                  AND similarity(normalized_key, :key) > :low
                ORDER BY trigram DESC
                LIMIT 8
                """
            ),
            {"key": key, "organizer_id": str(event.organizer_id), "low": LOW_TRIGRAM},
        ).all()
    except Exception:
        rows = []
        session.rollback()
        fallback = session.scalars(
            select(Series).where(Series.organizer_id == event.organizer_id)
        ).all()
        rows = [
            (str(row.id), row.canonical_title, row.normalized_key, 1.0 if row.normalized_key == key else 0.0)
            for row in fallback
            if row.normalized_key == key or row.normalized_key
        ]

    query_vec = None
    try:
        query_vec = embed_one(key)
    except Exception:
        query_vec = None

    out: list[SeriesCandidate] = []
    for row in rows:
        series_id, title, norm, trigram = row[0], row[1], row[2], float(row[3])
        series = session.get(Series, series_id)
        cosine = None
        if query_vec is not None and series is not None and series.embedding is not None:
            cosine = cosine_distance(query_vec, list(series.embedding))
        if trigram >= LOW_TRIGRAM or (cosine is not None and cosine < LOW_COSINE):
            out.append(SeriesCandidate(series_id, title, norm, trigram, cosine))
    return out


def _create_series(session: Session, event: Event, key: str) -> Series:
    now = datetime.now(timezone.utc)
    series = Series(
        organizer_id=event.organizer_id,
        canonical_title=event.title,
        normalized_key=key,
        editions_count=1,
        first_seen_at=now,
        last_seen_at=now,
    )
    session.add(series)
    session.flush()
    event.series_id = series.id
    return series


def _llm_tiebreak(event: Event, key: str, candidates: list[SeriesCandidate]) -> str | None:
    settings = get_settings()
    user = json.dumps(
        {
            "event_title": event.title,
            "normalized_key": key,
            "candidates": [
                {"id": item.series_id, "title": item.canonical_title, "key": item.normalized_key}
                for item in candidates
            ],
        }
    )
    try:
        result = complete_structured(
            prompt_name="series_match.md",
            model=settings.openai_model_match,
            user=user,
            schema=MATCH_SCHEMA,
            schema_name="series_match",
        )
    except LlmError:
        return None
    if not result.content.get("same_series"):
        return None
    return candidates[0].series_id if candidates else None
