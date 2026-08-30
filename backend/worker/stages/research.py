from __future__ import annotations

import logging
import re
from urllib.parse import urlparse

from sqlalchemy import select
from sqlalchemy.orm import Session

from core.config import get_settings
from core.embeddings import embed_texts
from core.llm import LlmError
from core.models import Event, EventChunk, IngestRun, Organizer, Series
from core.relevance import is_about_event
from core.websearch import SearchHit, cache_document, fetch_page, search_web

log = logging.getLogger(__name__)

CHUNK_CHARS = 3200  # ~800 tokens
CHUNK_OVERLAP = 400  # ~100 tokens

# Tokens too generic to identify an event. Without this, a title like
# "OFF THE RECORD - Vol 1" matches record shops and Bond reviews.
STOPWORDS = {
    "the", "and", "for", "with", "vol", "part", "meet", "meetup", "event",
    "events", "group", "club", "session", "edition", "first", "new", "your",
    "our", "off", "record", "live", "night", "day", "week", "month", "free",
}


def _tokens(text: str) -> set[str]:
    return {
        word
        for word in re.findall(r"[a-z0-9]+", text.lower())
        if len(word) > 3 and word not in STOPWORDS
    }


def is_relevant(hit: SearchHit, terms: set[str], city_terms: set[str]) -> bool:
    """Reject search results that are obviously about something else.

    Web search on a short, generic event title happily returns eBay listings and
    film reviews. Quotes pulled from those pages are *real* — the validator
    cannot catch them — so they would surface as sourced evidence for a claim
    about a Gurugram meetup. Filtering here is the only place this is catchable.
    """
    haystack = f"{hit.title} {hit.snippet} {hit.url}".lower()
    if any(city in haystack for city in city_terms):
        return True
    overlap = {term for term in terms if term in haystack}
    return len(overlap) >= 2


def chunk_text(text: str, size: int = CHUNK_CHARS, overlap: int = CHUNK_OVERLAP) -> list[str]:
    if not text:
        return []
    parts = []
    start = 0
    while start < len(text):
        end = min(len(text), start + size)
        parts.append(text[start:end])
        if end == len(text):
            break
        start = max(0, end - overlap)
    return parts


def research_new_events(session: Session, run: IngestRun | None = None) -> int:
    researched = 0
    events = session.scalars(
        select(Event).where(
            Event.id.notin_(select(EventChunk.event_id).where(EventChunk.event_id.is_not(None)).distinct())
        )
    ).all()
    for event in events:
        try:
            research_event(session, event, run)
            researched += 1
        except Exception:
            log.exception("research failed for %s", event.id)
    return researched


def research_event(session: Session, event: Event, run: IngestRun | None = None) -> None:
    series = session.get(Series, event.series_id) if event.series_id else None
    organizer = session.get(Organizer, event.organizer_id) if event.organizer_id else None

    settings = get_settings()
    city = event.city or "Gurugram"
    city_terms = set(settings.city_slug_list) | {city.lower()}

    title = series.canonical_title if series else event.title
    # Every query is scoped to the city. An unscoped title search is what
    # produced hotel reviews and record albums on the first run.
    queries = [f'"{title}" {city}']
    if organizer:
        queries.append(f"{organizer.name} {city} events")
    queries.append(f'"{title}" {city} recap')

    def keep(page) -> None:
        if page is None:
            return
        try:
            documents.append(cache_document(session, page))
        except Exception:
            log.warning("could not cache %s; continuing without it", page.url)

    documents = []
    listing = fetch_page(event.url)
    keep(listing)
    # Neither source supplies a description at discover time, so fill it from
    # the listing page we just fetched. Only when empty - never overwrite a
    # description a source did provide.
    if listing is not None and listing.description and not event.description_raw:
        event.description_raw = listing.description

    # The organiser's own page is fetched directly rather than searched for.
    # Previously the bare hostname ("www.meetup.com") was used as a search
    # query, which is pure noise.
    if organizer and organizer.url:
        parsed = urlparse(organizer.url)
        if parsed.scheme in {"http", "https"} and parsed.hostname:
            keep(fetch_page(organizer.url))

    terms = _tokens(title) | (_tokens(organizer.name) if organizer else set())
    for query in queries:
        for hit in search_web(query, session, run, limit=4):
            if not is_relevant(hit, terms, city_terms):
                log.info("dropped irrelevant result for %r: %s", query, hit.url)
                continue
            keep(fetch_page(hit.url))

    past = []
    if event.series_id:
        past = session.scalars(
            select(Event).where(Event.series_id == event.series_id, Event.id != event.id)
        ).all()

    chunks: list[tuple[str, str, str]] = []
    if event.description_raw:
        for part in chunk_text(event.description_raw):
            chunks.append(("description", event.url, part))

    # Only pages that are about *this event* become citable. A page that merely
    # shares the topic yields quotes that are real, verifiable and irrelevant -
    # the failure mode that survives every grounding check.
    for doc in documents:
        citable, reason = is_about_event(
            doc_url=doc.url,
            doc_text=doc.content,
            event_url=event.url,
            event_title=title,
            organizer_name=organizer.name if organizer else None,
            organizer_url=organizer.url if organizer else None,
        )
        if not citable:
            log.info("not citable for %r: %s (%s)", event.title[:40], doc.url, reason)
            continue
        for part in chunk_text(doc.content):
            chunks.append(("web_doc", doc.url, part))
    for past_event in past:
        body = past_event.description_raw or past_event.title
        for part in chunk_text(body):
            chunks.append(("past_edition", past_event.url, part))

    if not chunks:
        return

    try:
        vectors = embed_texts([part for _, _, part in chunks])
    except LlmError:
        log.warning("embedding failed for %s; chunks skipped", event.id)
        return

    for (source_type, source_url, content), vector in zip(chunks, vectors, strict=True):
        if not source_url:
            continue
        session.add(
            EventChunk(
                event_id=event.id,
                series_id=event.series_id,
                source_type=source_type,
                source_url=source_url,
                content=content,
                embedding=vector,
            )
        )
