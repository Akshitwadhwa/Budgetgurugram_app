from __future__ import annotations

import re

from core.config import get_settings

GURUGRAM_TERMS = re.compile(
    r"gurugram|gurgaon|\bggn\b|cyber ?city|cyber ?hub|udyog vihar|mg road|"
    r"golf course|sohna road|sector 29|dlf phase|huda city|leisure valley|old gurgaon",
    re.I,
)
FOREIGN_TERMS = re.compile(
    r"seoul|taipei|tel aviv|hawaii|melbourne|manila|jakarta|singapore|bangkok|"
    r"tokyo|osaka|london|paris|berlin|amsterdam|chicago|san francisco|new york|"
    r"los angeles|austin|boston|seattle|toronto|vancouver|sydney|dubai|abu dhabi|"
    r"nairobi|lagos|accra|cape town|jaipur|chennai|mumbai|bangalore|bengaluru|"
    r"hyderabad|pune|kolkata|ahmedabad|chandigarh|lucknow|indore|kochi|goa|"
    r"thailand|australia|philippines|indonesia|korea|taiwan|israel",
    re.I,
)
OTHER_INDIA_CITIES = re.compile(
    r"\b(delhi|new delhi|noida|faridabad|ghaziabad|greater noida)\b",
    re.I,
)
PLACEHOLDER_LOCATION = re.compile(r"^location listed", re.I)

AREA_COORDS = {
    "cyber city": (28.4952, 77.0894),
    "cyber hub": (28.4952, 77.0894),
    "dlf phase": (28.4952, 77.0894),
    "sector 29": (28.4672, 77.0323),
    "sector 44": (28.4512, 77.0721),
    "sector 52": (28.4298, 77.0826),
    "mg road": (28.4593, 77.0721),
    "golf course": (28.4425, 77.0941),
    "udyog vihar": (28.5122, 77.0472),
    "old gurgaon": (28.4605, 77.0167),
    "sohna road": (28.4121, 77.0612),
    "dwarka expressway": (28.4781, 77.0412),
}


def is_placeholder_location(value: str | None) -> bool:
    return not (value or "").strip() or bool(PLACEHOLDER_LOCATION.match(value.strip()))


def is_in_city_bounds(lat: float | None, lng: float | None) -> bool:
    if lat is None or lng is None:
        return False
    min_lat, min_lng, max_lat, max_lng = get_settings().bbox
    return min_lat <= lat <= max_lat and min_lng <= lng <= max_lng


def event_search_text(
    title: str = "",
    description: str = "",
    location: str = "",
    city: str = "",
) -> str:
    loc = "" if is_placeholder_location(location) else location
    stamped = city.lower() in get_settings().city_slug_list and not loc
    parts = [title, description, loc, "" if stamped else city]
    return " ".join(part for part in parts if part)


def is_gurugram_event(
    *,
    title: str = "",
    description: str = "",
    location: str = "",
    city: str = "",
    lat: float | None = None,
    lng: float | None = None,
    geocode_quality: str | None = None,
) -> bool:
    city_l = (city or "").lower()
    if any(slug in city_l for slug in get_settings().city_slug_list):
        return True
    if (
        is_in_city_bounds(lat, lng)
        and not is_placeholder_location(location)
        and geocode_quality != "city-default"
    ):
        return True
    searchable = event_search_text(title, description, location, city)
    if not searchable:
        return False
    if FOREIGN_TERMS.search(searchable) and not GURUGRAM_TERMS.search(searchable):
        return False
    if OTHER_INDIA_CITIES.search(searchable) and not GURUGRAM_TERMS.search(searchable):
        return False
    return bool(GURUGRAM_TERMS.search(searchable))


def classify_geocode(
    lat: float | None,
    lng: float | None,
    location: str | None,
    city: str | None,
) -> tuple[float | None, float | None, str]:
    """Never invent a venue pin. City-default and unlocated keep null coords."""
    if is_in_city_bounds(lat, lng) and not is_placeholder_location(location):
        return lat, lng, "exact"

    haystack = f"{'' if is_placeholder_location(location) else location or ''} {city or ''}".lower()
    for keyword, coords in AREA_COORDS.items():
        if keyword in haystack:
            return coords[0], coords[1], "area"

    city_l = (city or "").lower()
    if any(slug in city_l for slug in get_settings().city_slug_list) or GURUGRAM_TERMS.search(haystack):
        return None, None, "city-default"
    return None, None, "unlocated"
