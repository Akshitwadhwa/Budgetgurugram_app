from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from core.models import Event, EventEnrichment, Series


def infer_cadence(starts: list[datetime]) -> str | None:
    if len(starts) < 2:
        return None
    ordered = sorted(starts)
    gaps = [(b - a).days for a, b in zip(ordered, ordered[1:], strict=False)]
    if not gaps:
        return None
    avg = sum(gaps) / len(gaps)
    if avg <= 10:
        return "weekly"
    if avg <= 40:
        return "monthly"
    return "irregular"


def sweep(session: Session) -> None:
    now = datetime.now(timezone.utc)
    events = session.scalars(select(Event)).all()
    for event in events:
        end = event.ends_at or event.starts_at
        if end.tzinfo is None:
            end = end.replace(tzinfo=timezone.utc)
        if end < now and event.status == "upcoming":
            event.status = "past"

    for series in session.scalars(select(Series)).all():
        editions = session.scalars(select(Event).where(Event.series_id == series.id)).all()
        series.editions_count = len(editions)
        if editions:
            series.last_seen_at = max(item.last_seen_at for item in editions)
        series.cadence = infer_cadence([item.starts_at for item in editions])
        formats = []
        for event in editions:
            enrichment = session.get(EventEnrichment, event.id)
            if enrichment:
                formats.append(enrichment.true_format)
        if formats:
            series.format_verdict = Counter(formats).most_common(1)[0][0]
