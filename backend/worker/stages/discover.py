from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from core.models import Event, IngestRun, Organizer, Source
from core.title_normalize import normalize_name
from worker.guards import evaluate_zero_result
from worker.sources import adapter_for
from worker.sources.base import DiscoveredEvent

log = logging.getLogger(__name__)


def last_successful_found(session: Session, source_id: str) -> int:
    run = session.scalar(
        select(IngestRun)
        .where(IngestRun.source_id == source_id, IngestRun.status == "ok")
        .order_by(IngestRun.started_at.desc())
        .limit(1)
    )
    return run.events_found if run else 0


def discover_source(session: Session, source: Source) -> IngestRun:
    now = datetime.now(timezone.utc)
    run = IngestRun(source_id=source.id, started_at=now, status="running", errors=[])
    session.add(run)
    session.flush()

    try:
        adapter = adapter_for(source.id)
        found_events = adapter.fetch(source.config or {})
    except Exception as exc:
        log.exception("source %s threw", source.id)
        run.status = "failed"
        run.finished_at = datetime.now(timezone.utc)
        run.errors = [str(exc)]
        return run

    found = len(found_events)
    previous = last_successful_found(session, source.id)
    guard = evaluate_zero_result(found, previous)
    run.events_found = found

    if guard == "suspect":
        log.error("%s returned 0 events; previous run found %s", source.id, previous)
        run.status = "suspect"
        run.finished_at = datetime.now(timezone.utc)
        run.errors = [f"{source.id} returned 0 events; previous run found {previous}"]
        return run

    new_count = 0
    for item in found_events:
        created = upsert_event(session, item)
        if created:
            new_count += 1
    run.events_new = new_count
    run.status = "ok"
    run.finished_at = datetime.now(timezone.utc)
    return run


def upsert_event(session: Session, item: DiscoveredEvent) -> bool:
    now = datetime.now(timezone.utc)
    existing = session.scalar(
        select(Event).where(
            Event.source_id == item.source_id,
            Event.source_event_id == item.source_event_id,
        )
    )
    organizer = _upsert_organizer(session, item)
    if existing:
        existing.title = item.title
        existing.description_raw = item.description
        existing.starts_at = item.starts_at
        existing.ends_at = item.ends_at
        existing.venue_name = item.venue_name
        existing.address = item.address
        existing.lat = item.lat
        existing.lng = item.lng
        existing.geocode_quality = item.geocode_quality
        existing.price_raw = item.price_raw
        existing.price_value = item.price_value
        existing.url = item.url
        existing.city = item.city
        existing.raw = item.raw
        existing.last_seen_at = now
        if organizer:
            existing.organizer_id = organizer.id
        return False

    event = Event(
        source_id=item.source_id,
        source_event_id=item.source_event_id,
        title=item.title,
        description_raw=item.description,
        starts_at=item.starts_at,
        ends_at=item.ends_at,
        venue_name=item.venue_name,
        address=item.address,
        lat=item.lat,
        lng=item.lng,
        geocode_quality=item.geocode_quality,
        price_raw=item.price_raw,
        price_value=item.price_value,
        url=item.url,
        city=item.city,
        status="upcoming",
        raw=item.raw,
        organizer_id=organizer.id if organizer else None,
        first_seen_at=now,
        last_seen_at=now,
    )
    session.add(event)
    return True


def _upsert_organizer(session: Session, item: DiscoveredEvent) -> Organizer | None:
    if not item.organizer_name and not item.organizer_ref:
        return None
    ref = item.organizer_ref or normalize_name(item.organizer_name or "")
    existing = session.scalar(
        select(Organizer).where(Organizer.source_id == item.source_id, Organizer.source_ref == ref)
    )
    now = datetime.now(timezone.utc)
    if existing:
        existing.last_seen_at = now
        if item.organizer_name:
            existing.name = item.organizer_name
            existing.normalized_name = normalize_name(item.organizer_name)
        return existing
    organizer = Organizer(
        source_id=item.source_id,
        source_ref=ref,
        name=item.organizer_name or ref,
        normalized_name=normalize_name(item.organizer_name or ref),
        url=item.organizer_url,
        last_seen_at=now,
    )
    session.add(organizer)
    session.flush()
    return organizer
