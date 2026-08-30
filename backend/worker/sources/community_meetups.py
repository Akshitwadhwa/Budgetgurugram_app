from __future__ import annotations

from typing import Any

import httpx

from core.geo import classify_geocode, is_gurugram_event
from worker.sources.base import DiscoveredEvent
from worker.sources.parse import (
    collect_events,
    canonical_luma_url,
    find_luma_urls,
    first,
    number_of,
    parse_dt,
    parse_json_scripts,
    text_of,
)

USER_AGENT = "GurugramCommons event indexer/1.0 (+public source attribution)"
DEFAULT_URL = "https://lu.ma/CommunityMeetups"


class CommunityMeetupsSource:
    source_id = "community"

    def fetch(self, config: dict[str, Any]) -> list[DiscoveredEvent]:
        url = config.get("url") or DEFAULT_URL
        response = httpx.get(url, headers={"user-agent": USER_AGENT}, timeout=25, follow_redirects=True)
        response.raise_for_status()
        html = response.text
        events: list[DiscoveredEvent] = []
        for raw in collect_events(parse_json_scripts(html)):
            event = _from_schema(raw, url)
            if event:
                events.append(event)

        page_urls = find_luma_urls(html, url)
        for batch_start in range(0, len(page_urls), 6):
            batch = page_urls[batch_start : batch_start + 6]
            for page_url in batch:
                try:
                    page = httpx.get(page_url, headers={"user-agent": USER_AGENT}, timeout=20, follow_redirects=True)
                    page.raise_for_status()
                except Exception:
                    continue
                page_events = collect_events(parse_json_scripts(page.text))
                if page_events:
                    for raw in page_events:
                        event = _from_schema(raw, page_url)
                        if event:
                            events.append(event)
                else:
                    soup_title = first(_meta(page.text, "og:title"))
                    start = _meta(page.text, "event:start_time")
                    if soup_title and start:
                        event = _from_schema({"name": soup_title, "startDate": start, "url": page_url}, page_url)
                        if event:
                            events.append(event)
        return _dedupe(events)

    def fetch_organizer_history(self, organizer_ref: str, config: dict[str, Any]) -> list[DiscoveredEvent]:
        return self.fetch({**config, "url": organizer_ref})


def _meta(html: str, property_name: str) -> str:
    import re

    forward = re.search(
        rf'<meta[^>]+(?:property|name)=["\']{property_name}["\'][^>]+content=["\']([^"\']*)["\']',
        html,
        re.I,
    )
    if forward:
        return forward.group(1)
    reverse = re.search(
        rf'<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']{property_name}["\']',
        html,
        re.I,
    )
    return reverse.group(1) if reverse else ""


def _from_schema(raw: dict[str, Any], page_url: str) -> DiscoveredEvent | None:
    title = first(raw.get("name"), raw.get("title"))
    starts = parse_dt(raw.get("startDate") or raw.get("start_at") or raw.get("start_time"))
    # Luma's API returns `url` as a bare slug ("m0o37oik"), not a URL. Stored
    # raw it produced un-fetchable rows ("Request URL is missing an
    # 'http://' or 'https://' protocol") that also duplicated the real event,
    # because source_event_id is derived from this value.
    url = canonical_luma_url(first(raw.get("url"), page_url), page_url)
    if not title or not starts or not url:
        return None
    location = raw.get("location") or {}
    address = location.get("address") if isinstance(location, dict) else {}
    # No "Gurugram" fallback. A defaulted city short-circuits is_gurugram_event
    # on its first line, so fabricating one here disabled the city filter for
    # every event this source produced.
    city = first(address.get("addressLocality") if isinstance(address, dict) else "")
    label = first(
        location.get("name") if isinstance(location, dict) else "",
        address.get("streetAddress") if isinstance(address, dict) else "",
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
    return DiscoveredEvent(
        source_id="community",
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
        organizer_name="CommunityMeetups",
        organizer_ref="communitymeetups",
        raw=raw if isinstance(raw, dict) else {"url": page_url},
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
