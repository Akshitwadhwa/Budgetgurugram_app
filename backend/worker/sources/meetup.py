from __future__ import annotations

from typing import Any

import httpx

from core.geo import classify_geocode, is_gurugram_event
from core.guest_count import extract_guest_count, guest_count_source_for
from worker.sources.base import DiscoveredEvent
from worker.sources.parse import collect_events, first, number_of, parse_dt, parse_json_scripts, text_of

USER_AGENT = "GurugramCommons event indexer/1.0 (+public source attribution)"
DEFAULT_URL = "https://www.meetup.com/find/in--gurgaon/"


class MeetupSource:
    source_id = "meetup"

    def fetch(self, config: dict[str, Any]) -> list[DiscoveredEvent]:
        url = config.get("url") or DEFAULT_URL
        response = httpx.get(url, headers={"user-agent": USER_AGENT}, timeout=25, follow_redirects=True)
        response.raise_for_status()
        objects = parse_json_scripts(response.text)
        events: list[DiscoveredEvent] = []
        for raw in collect_events(objects):
            event = _from_schema(raw)
            if event:
                events.append(event)
        return events

    def fetch_organizer_history(self, organizer_ref: str, config: dict[str, Any]) -> list[DiscoveredEvent]:
        url = organizer_ref if organizer_ref.startswith("http") else f"https://www.meetup.com/{organizer_ref}/events/past/"
        try:
            response = httpx.get(url, headers={"user-agent": USER_AGENT}, timeout=25, follow_redirects=True)
            response.raise_for_status()
        except Exception:
            return []
        events: list[DiscoveredEvent] = []
        for raw in collect_events(parse_json_scripts(response.text)):
            event = _from_schema(raw)
            if event:
                events.append(event)
        return events


def _from_schema(raw: dict[str, Any]) -> DiscoveredEvent | None:
    title = first(raw.get("name"), raw.get("title"))
    starts = parse_dt(raw.get("startDate") or raw.get("start_time"))
    url = first(raw.get("url"), raw.get("event_url"))
    if not title or not starts or not url:
        return None
    location = raw.get("location") or {}
    address = location.get("address") if isinstance(location, dict) else {}
    city = first(
        address.get("addressLocality") if isinstance(address, dict) else "",
        location.get("name") if isinstance(location, dict) else "",
        "Gurugram",
    )
    label = first(
        location.get("name") if isinstance(location, dict) else "",
        address.get("streetAddress") if isinstance(address, dict) else "",
        city,
    )
    geo = location.get("geo") if isinstance(location, dict) else {}
    lat = number_of(geo.get("latitude") if isinstance(geo, dict) else None)
    lng = number_of(geo.get("longitude") if isinstance(geo, dict) else None)
    lat, lng, quality = classify_geocode(lat, lng, label, city)
    if not is_gurugram_event(
        title=title,
        description=text_of(raw.get("description")),
        location=label,
        city=city,
        lat=lat,
        lng=lng,
        geocode_quality=quality,
    ):
        return None
    organizer = raw.get("organizer") or raw.get("group") or {}
    return DiscoveredEvent(
        source_id="meetup",
        source_event_id=url,
        title=title,
        url=url,
        starts_at=starts,
        ends_at=parse_dt(raw.get("endDate")),
        description=text_of(raw.get("description"))[:2000],
        venue_name=label or None,
        address=label or None,
        city=city or "Gurugram",
        lat=lat,
        lng=lng,
        geocode_quality=quality,
        price_raw=first(raw.get("offers", {}).get("price") if isinstance(raw.get("offers"), dict) else "", "See source"),
        organizer_name=first(organizer.get("name") if isinstance(organizer, dict) else "") or None,
        organizer_ref=first(organizer.get("url") if isinstance(organizer, dict) else "") or None,
        organizer_url=first(organizer.get("url") if isinstance(organizer, dict) else "") or None,
        guest_count=extract_guest_count(raw),
        guest_count_source=guest_count_source_for("meetup") if extract_guest_count(raw) else None,
        raw=raw,
    )
