from __future__ import annotations

import logging

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from core.embeddings import cosine_similarity, embed_one
from core.llm import LlmError
from core.models import Event, EventSimilarity

log = logging.getLogger(__name__)


def index_events(session: Session) -> int:
    upcoming = session.scalars(select(Event).where(Event.status == "upcoming")).all()
    indexed = 0
    for event in upcoming:
        if event.embedding is None:
            try:
                event.embedding = embed_one(f"{event.title}\n{event.description_raw}")
            except LlmError:
                log.warning("embedding failed for event %s", event.id)
                continue
        indexed += 1

    session.flush()
    with_vectors = [event for event in upcoming if event.embedding is not None]
    session.execute(delete(EventSimilarity))
    for event in with_vectors:
        neighbours: list[tuple[float, Event]] = []
        for other in with_vectors:
            if other.id == event.id:
                continue
            if event.series_id and other.series_id and event.series_id == other.series_id:
                continue
            neighbours.append((cosine_similarity(list(event.embedding), list(other.embedding)), other))
        neighbours.sort(key=lambda item: item[0], reverse=True)
        for score, other in neighbours[:5]:
            session.add(EventSimilarity(event_id=event.id, similar_id=other.id, score=score))
    return indexed
