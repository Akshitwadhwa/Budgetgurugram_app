from __future__ import annotations

from core.confidence import confidence_band
from core.models import Event, EventEnrichment, Series

from app.schemas.events import (
    EventListItem,
    EventSummary,
    EvidenceOut,
    SeriesOut,
    VerdictOut,
)


def event_source_label(event: Event) -> str:
    if event.source and event.source.display_name:
        return event.source.display_name
    return event.source_id.title()


def to_event_summary(event: Event) -> EventSummary:
    lat, lng = event.lat, event.lng
    if event.geocode_quality in {"city-default", "unlocated"}:
        lat, lng = None, None
    return EventSummary(
        id=str(event.id),
        title=event.title,
        starts_at=event.starts_at,
        ends_at=event.ends_at,
        venue_name=event.venue_name,
        address=event.address,
        lat=lat,
        lng=lng,
        geocode_quality=event.geocode_quality,
        price_raw=event.price_raw or "See source",
        url=event.url,
        source=event_source_label(event),
        description=event.description_raw or "",
        city=event.city,
        series_id=str(event.series_id) if event.series_id else None,
    )


def to_list_item(event: Event) -> EventListItem:
    summary = to_event_summary(event)
    enrichment = event.enrichment
    band = confidence_band(enrichment.format_confidence) if enrichment else None
    return EventListItem(
        **summary.model_dump(),
        verdict_band=band,
        has_verdict=enrichment is not None,
        verdict_format=enrichment.true_format if enrichment else None,
    )


def to_verdict(enrichment: EventEnrichment) -> VerdictOut:
    evidence = [
        EvidenceOut(
            claim=item.get("claim", ""),
            source_url=item.get("source_url") or item.get("sourceUrl") or "",
            source_title=item.get("source_title") or item.get("sourceTitle") or "",
            quote=item.get("quote", ""),
        )
        for item in enrichment.evidence
    ]
    return VerdictOut(
        true_format=enrichment.true_format,
        confidence=enrichment.format_confidence,
        band=confidence_band(enrichment.format_confidence) or "unclear",
        level=enrichment.level,
        hands_on=enrichment.hands_on,
        expect=enrichment.expect,
        who_should_come=list(enrichment.who_should_come or []),
        prep_needed=enrichment.prep_needed,
        watch_outs=list(enrichment.watch_outs or []),
        evidence=evidence,
    )


def series_disagrees(series: Series | None, enrichment: EventEnrichment | None) -> bool:
    if not series or not enrichment or not series.format_verdict or not enrichment.true_format:
        return False
    return series.format_verdict != enrichment.true_format


def to_series_out(series: Series | None, enrichment: EventEnrichment | None) -> SeriesOut | None:
    if series is None:
        return None
    return SeriesOut(
        id=str(series.id),
        canonical_title=series.canonical_title,
        editions_count=series.editions_count,
        cadence=series.cadence,
        format_verdict=series.format_verdict,
        disagrees_with_event=series_disagrees(series, enrichment),
    )
