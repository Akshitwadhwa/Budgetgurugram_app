from __future__ import annotations

from datetime import datetime

from app.schemas.common import APIModel


class EvidenceOut(APIModel):
    claim: str
    source_url: str
    source_title: str
    quote: str


class EventSummary(APIModel):
    id: str
    title: str
    starts_at: datetime
    ends_at: datetime | None = None
    venue_name: str | None = None
    address: str | None = None
    lat: float | None = None
    lng: float | None = None
    geocode_quality: str | None = None
    price_raw: str | None = "See source"
    url: str
    source: str
    description: str = ""
    city: str = "Gurugram"
    series_id: str | None = None
    about: str = ""
    guest_count: int | None = None
    guest_count_source: str | None = None
    guest_count_at: datetime | None = None


class EventListItem(EventSummary):
    verdict_band: str | None = None
    has_verdict: bool = False
    # Carried on the list so a card can show the reading itself
    # ("Likely a workshop"), not just how confident we are. Without it the
    # list can only show a confidence with nothing to be confident about.
    verdict_format: str | None = None


class EventListResponse(APIModel):
    events: list[EventListItem]
    next_cursor: str | None = None


class VerdictOut(APIModel):
    true_format: str
    confidence: float
    band: str
    level: str | None = None
    hands_on: bool | None = None
    expect: str
    who_should_come: list[str] = []
    prep_needed: str | None = None
    watch_outs: list[str] = []
    evidence: list[EvidenceOut]


class SeriesOut(APIModel):
    id: str
    canonical_title: str
    editions_count: int
    cadence: str | None = None
    format_verdict: str | None = None
    disagrees_with_event: bool = False


class PastEditionOut(APIModel):
    id: str
    title: str
    starts_at: datetime
    url: str


class SimilarEventOut(APIModel):
    id: str
    title: str
    starts_at: datetime
    score: float


class EventDetailResponse(APIModel):
    event: EventSummary
    verdict: VerdictOut | None = None
    series: SeriesOut | None = None
    past_editions: list[PastEditionOut] = []
    similar: list[SimilarEventOut] = []
