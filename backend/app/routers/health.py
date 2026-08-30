from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from core.config import get_settings
from core.models import Event, EventEnrichment, IngestRun, Source

from app.deps import get_db, get_device
from app.schemas.health import HealthResponse, SourceHealth

router = APIRouter(prefix="/v1", tags=["health"], dependencies=[Depends(get_device)])


@router.get("/health", response_model=HealthResponse)
def health(session: Session = Depends(get_db)) -> HealthResponse:
    now = datetime.now(timezone.utc)
    stale_after = timedelta(hours=get_settings().scrape_interval_hours * 2)

    upcoming = session.scalar(select(func.count()).select_from(Event).where(Event.status == "upcoming")) or 0
    enriched = session.scalar(
        select(func.count())
        .select_from(EventEnrichment)
        .join(Event, Event.id == EventEnrichment.event_id)
        .where(Event.status == "upcoming")
    ) or 0

    sources = []
    for source in session.scalars(select(Source).order_by(Source.id)).all():
        run = session.scalar(
            select(IngestRun)
            .where(IngestRun.source_id == source.id)
            .order_by(IngestRun.started_at.desc())
            .limit(1)
        )
        finished = run.finished_at if run else None
        sources.append(
            SourceHealth(
                source_id=source.id,
                display_name=source.display_name,
                last_status=run.status if run else None,
                last_finished_at=finished,
                events_found=run.events_found if run else 0,
                stale=finished is None or (now - finished) > stale_after,
            )
        )

    return HealthResponse(
        ok=all(item.last_status in {None, "ok", "suspect"} for item in sources),
        upcoming_events=int(upcoming),
        enriched_upcoming=int(enriched),
        sources=sources,
    )
