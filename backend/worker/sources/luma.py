from __future__ import annotations

from typing import Any

import httpx

from core.config import get_settings
from core.geo import classify_geocode, is_gurugram_event
from core.guest_count import extract_guest_count, guest_count_source_for
from worker.sources.base import DiscoveredEvent
from worker.sources.parse import canonical_luma_url, first, number_of, parse_dt, text_of

USER_AGENT = "GurugramCommons event indexer/1.0 (+public source attribution)"


class LumaSource:
    source_id = "luma"

    def fetch(self, config: dict[str, Any]) -> list[DiscoveredEvent]:
        queries = config.get("queries") or get_settings().city_slug_list
        events: list[DiscoveredEvent] = []
        for query in queries:
            events.extend(self._discover(query))
        return _dedupe(events)

    def fetch_organizer_history(self, organizer_ref: str, config: dict[str, Any]) -> list[DiscoveredEvent]:
        url = organizer_ref if organizer_ref.startswith("http") else f"https://lu.ma/user/{organizer_ref}"
        try:
            response = httpx.get(url, headers={"user-agent": USER_AGENT}, timeout=20)
            response.raise_for_status()
        except Exception:
            return []
        # History pages vary; discover already covers live listings. Partial backfill is OK.
        return []

    def _discover(self, query: str) -> list[DiscoveredEvent]:
        url = "https://api.lu.ma/discover/get-paginated-events"
        response = httpx.get(
            url,
            params={"pagination_limit": "50", "query": query},
            headers={"accept": "application/json", "user-agent": USER_AGENT},
            timeout=25,
        )
        response.raise_for_status()
        payload = response.json()
        out: list[DiscoveredEvent] = []
        for entry in payload.get("entries") or []:
            raw = entry.get("event") or entry
            event = _from_luma_api(raw)
            if event:
                out.append(event)
        return out


def _from_luma_api(raw: dict[str, Any]) -> DiscoveredEvent | None:
    geo = raw.get("geo_address_info") or {}
    title = first(raw.get("name"), raw.get("title"))
    starts = parse_dt(raw.get("start_at") or raw.get("start_at_iso"))
    if not title or not starts:
        return None
    raw_url = first(raw.get("url"), raw.get("event_url"), raw.get("api_id", "").replace("evt-", ""))
    url = canonical_luma_url(raw_url) if raw_url.startswith("http") else (f"https://lu.ma/{raw_url}" if raw_url else "")
    if not url.startswith("http"):
        return None
    location = first(geo.get("full_address"), geo.get("city"), raw.get("location"))
    city = first(geo.get("city"), "Gurugram")
    lat = number_of(geo.get("latitude"), raw.get("lat"))
    lng = number_of(geo.get("longitude"), raw.get("lng"))
    lat, lng, quality = classify_geocode(lat, lng, location, city)
    if not is_gurugram_event(
        title=title,
        description=text_of(raw.get("description")),
        location=location,
        city=city,
        lat=lat,
        lng=lng,
        geocode_quality=quality,
    ):
        return None
    host = raw.get("calendar") or raw.get("host") or {}
    going = extract_guest_count(raw)
    return DiscoveredEvent(
        source_id="luma",
        source_event_id=first(raw.get("api_id"), url),
        title=title,
        url=url,
        starts_at=starts,
        ends_at=parse_dt(raw.get("end_at") or raw.get("end_at_iso")),
        description=text_of(raw.get("description"))[:2000],
        venue_name=first(geo.get("full_address"), location) or None,
        address=first(geo.get("full_address"), location) or None,
        city=city or "Gurugram",
        lat=lat,
        lng=lng,
        geocode_quality=quality,
        price_raw=first(raw.get("price"), "See source"),
        organizer_name=first(host.get("name"), host.get("title")) or None,
        organizer_ref=first(host.get("slug"), host.get("api_id")) or None,
        organizer_url=first(host.get("url")) or None,
        guest_count=going,
        guest_count_source=guest_count_source_for("luma") if going else None,
        raw=raw,
    )


def _dedupe(events: list[DiscoveredEvent]) -> list[DiscoveredEvent]:
    seen: set[str] = set()
    out: list[DiscoveredEvent] = []
    for event in events:
        if event.source_event_id in seen:
            continue
        seen.add(event.source_event_id)
        out.append(event)
    return out
