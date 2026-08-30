from __future__ import annotations

import logging
from urllib.parse import urlparse

from sqlalchemy import select
from sqlalchemy.orm import Session

from core.embeddings import embed_texts
from core.llm import LlmError
from core.models import Event, EventChunk, IngestRun, Organizer, Series
from core.websearch import cache_document, fetch_page, search_web

log = logging.getLogger(__name__)

CHUNK_CHARS = 3200  # ~800 tokens
CHUNK_OVERLAP = 400  # ~100 tokens


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

    queries = [
        series.canonical_title if series else event.title,
        organizer.name if organizer else None,
        f'"{event.title}" review',
    ]
    if organizer and organizer.url:
        host = urlparse(organizer.url).hostname
        if host:
            queries.append(host)
    queries = [query for query in queries if query]

    documents = []
    listing = fetch_page(event.url)
    if listing:
        documents.append(cache_document(session, listing))

    for query in queries:
        for hit in search_web(query, session, run, limit=4):
            page = fetch_page(hit.url)
            if page:
                documents.append(cache_document(session, page))

    past = []
    if event.series_id:
        past = session.scalars(
            select(Event).where(Event.series_id == event.series_id, Event.id != event.id)
        ).all()

    chunks: list[tuple[str, str, str]] = []
    if event.description_raw:
        for part in chunk_text(event.description_raw):
            chunks.append(("description", event.url, part))
    for doc in documents:
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
