from __future__ import annotations

import base64
import json
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from core.config import get_settings
from core.models import Event, EventSimilarity

from app.deps import get_db, get_device
from app.presenters import to_event_summary, to_list_item, to_series_out, to_verdict
from app.schemas.events import (
    EventDetailResponse,
    EventListResponse,
    PastEditionOut,
    SimilarEventOut,
)

router = APIRouter(prefix="/v1", tags=["events"], dependencies=[Depends(get_device)])

_LIST_CACHE: dict[str, tuple[float, EventListResponse]] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _decode_cursor(cursor: str | None) -> tuple[datetime, str] | None:
    if not cursor:
        return None
    try:
        raw = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
        return datetime.fromisoformat(raw["t"]), raw["id"]
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid cursor") from exc


def _encode_cursor(starts_at: datetime, event_id: str) -> str:
    payload = json.dumps({"t": starts_at.isoformat(), "id": event_id}).encode()
    return base64.urlsafe_b64encode(payload).decode()


@router.get("/events", response_model=EventListResponse)
def list_events(
    from_: datetime | None = Query(default=None, alias="from"),
    to: datetime | None = Query(default=None),
    filter: str | None = Query(default=None, pattern="^(today|week|free)$"),
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = None,
    session: Session = Depends(get_db),
) -> EventListResponse:
    settings = get_settings()
    cache_key = f"{from_}|{to}|{filter}|{limit}|{cursor}"
    hit = _LIST_CACHE.get(cache_key)
    now_ts = _now().timestamp()
    if hit and now_ts - hit[0] < settings.list_cache_seconds:
        return hit[1]

    now = _now()
    start = from_ or now
    end = to
    if filter == "today":
        end = datetime(now.year, now.month, now.day, tzinfo=timezone.utc) + timedelta(days=1)
    elif filter == "week":
        end = now + timedelta(days=7)

    stmt = (
        select(Event)
        .options(joinedload(Event.source), joinedload(Event.enrichment))
        .where(Event.status == "upcoming")
        .where(Event.starts_at >= start)
        .order_by(Event.starts_at.asc(), Event.id.asc())
    )
    if end is not None:
        stmt = stmt.where(Event.starts_at < end)
    if filter == "free":
        stmt = stmt.where(or_(Event.price_raw.ilike("%free%"), Event.price_value == 0))

    decoded = _decode_cursor(cursor)
    if decoded:
        cursor_time, cursor_id = decoded
        stmt = stmt.where(
            or_(
                Event.starts_at > cursor_time,
                (Event.starts_at == cursor_time) & (Event.id > UUID(cursor_id)),
            )
        )

    rows = session.scalars(stmt.limit(limit + 1)).unique().all()
    page = rows[:limit]
    next_cursor = None
    if len(rows) > limit:
        last = page[-1]
        next_cursor = _encode_cursor(last.starts_at, str(last.id))

    payload = EventListResponse(events=[to_list_item(event) for event in page], next_cursor=next_cursor)
    _LIST_CACHE[cache_key] = (now_ts, payload)
    return payload


@router.get("/events/{event_id}", response_model=EventDetailResponse)
def get_event(event_id: UUID, session: Session = Depends(get_db)) -> EventDetailResponse:
    event = session.scalar(
        select(Event)
        .options(
            joinedload(Event.source),
            joinedload(Event.enrichment),
            joinedload(Event.series),
        )
        .where(Event.id == event_id)
    )
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    past: list[PastEditionOut] = []
    if event.series_id:
        past_rows = session.scalars(
            select(Event)
            .where(Event.series_id == event.series_id, Event.id != event.id)
            .order_by(Event.starts_at.desc())
            .limit(12)
        ).all()
        past = [
            PastEditionOut(id=str(row.id), title=row.title, starts_at=row.starts_at, url=row.url)
            for row in past_rows
        ]

    similar_rows = session.execute(
        select(EventSimilarity, Event)
        .join(Event, Event.id == EventSimilarity.similar_id)
        .where(EventSimilarity.event_id == event.id)
        .order_by(EventSimilarity.score.desc())
        .limit(5)
    ).all()
    similar = [
        SimilarEventOut(id=str(row.id), title=row.title, starts_at=row.starts_at, score=link.score)
        for link, row in similar_rows
    ]

    return EventDetailResponse(
        event=to_event_summary(event),
        verdict=to_verdict(event.enrichment) if event.enrichment else None,
        series=to_series_out(event.series, event.enrichment),
        past_editions=past,
        similar=similar,
    )
