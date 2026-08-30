from datetime import datetime

from app.schemas.common import APIModel


class SourceHealth(APIModel):
    source_id: str
    display_name: str
    last_status: str | None = None
    last_finished_at: datetime | None = None
    events_found: int = 0
    stale: bool = False


class HealthResponse(APIModel):
    ok: bool
    upcoming_events: int
    enriched_upcoming: int
    sources: list[SourceHealth]
