from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Protocol


@dataclass
class DiscoveredEvent:
    source_id: str
    source_event_id: str
    title: str
    url: str
    starts_at: datetime
    ends_at: datetime | None = None
    description: str = ""
    venue_name: str | None = None
    address: str | None = None
    city: str = "Gurugram"
    lat: float | None = None
    lng: float | None = None
    geocode_quality: str | None = None
    price_raw: str = "See source"
    price_value: float | None = None
    organizer_name: str | None = None
    organizer_ref: str | None = None
    organizer_url: str | None = None
    guest_count: int | None = None
    guest_count_source: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


class SourceAdapter(Protocol):
    source_id: str

    def fetch(self, config: dict[str, Any]) -> list[DiscoveredEvent]:
        ...

    def fetch_organizer_history(self, organizer_ref: str, config: dict[str, Any]) -> list[DiscoveredEvent]:
        ...
