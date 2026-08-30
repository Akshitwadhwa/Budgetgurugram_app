from __future__ import annotations

from typing import Any


def _as_count(value: Any) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, dict):
        for key in ("going", "approved", "accepted", "count", "yes", "total"):
            found = _as_count(value.get(key))
            if found is not None:
                return found
        return None
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    if number < 1 or number > 100_000:
        return None
    return number


def extract_guest_count(raw: dict[str, Any] | None) -> int | None:
    """Public going-count only. Never treat capacity or waitlist as attendance."""
    if not raw:
        return None
    event = raw.get("event") if isinstance(raw.get("event"), dict) else raw
    if not isinstance(event, dict):
        return None

    for key in (
        "guest_count",
        "guests_count",
        "accepted_count",
        "yes_rsvp_count",
        "going_count",
        "attendee_count",
        "number_of_active_guests",
    ):
        found = _as_count(event.get(key))
        if found is not None:
            return found

    for key in ("guest_counts", "guests", "guest"):
        found = _as_count(event.get(key))
        if found is not None:
            return found

    attendees = event.get("attendee")
    if isinstance(attendees, list) and 0 < len(attendees) <= 100_000:
        return len(attendees)
    return None


def guest_count_source_for(source_id: str) -> str:
    if source_id == "luma" or source_id == "community":
        return "luma-public"
    if source_id == "meetup":
        return "meetup-public"
    return "source-public"
