"""Decide whether a discovered event actually belongs to the target city.

This exists because `DiscoveredEvent.city` defaults to `"Gurugram"` and nothing
verified it, so an all-India calendar like CommunityMeetups happily filed
Bengaluru, Mumbai, Surat and Nagpur events as Gurugram. They then went through
paid enrichment, and one verdict ended up stating outright that "the listing
places it in Bengaluru, not Gurugram".

Spec decision D2 is Gurugram-only, so this is the gate that enforces it.

The rules, in order:

1. **Real coordinates decide.** Inside the bounding box, accept; outside,
   reject. Coordinates that are only a city-centre fallback are not "real" and
   are ignored here - trusting them would accept everything.
2. **A named rival city rejects**, unless the target city is *also* named
   (e.g. "Bengaluru founders meet Gurugram chapter").
3. **Otherwise accept.** A local listing that simply omits its city is far more
   common than an out-of-town one, so defaulting to reject would quietly empty
   the app.
"""

from __future__ import annotations

import re

# Cities whose events regularly appear on national calendars. Matching is on
# word boundaries so "Surat" does not match "Suratgarh".
OTHER_CITIES = {
    "bengaluru", "bangalore", "mumbai", "pune", "hyderabad", "chennai",
    "kolkata", "ahmedabad", "surat", "nagpur", "jaipur", "kochi", "cochin",
    "indore", "chandigarh", "lucknow", "bhopal", "coimbatore", "vizag",
    "visakhapatnam", "goa", "trivandrum", "thiruvananthapuram", "patna",
    "guwahati", "bhubaneswar", "mysuru", "mysore", "udaipur", "dehradun",
}


def _mentions(text: str, needles: set[str] | list[str]) -> set[str]:
    """Find city names, including inside CamelCase compounds.

    Two patterns are needed and neither alone is sufficient:

    * ``\\bcity\\b`` catches "Meetup - Bengaluru" but misses "NagpurStartups",
      where no word boundary follows the city name.
    * A CamelCase lookahead catches "NagpurStartups" while still rejecting
      "Suratgarh" and "Goal", which continue in lowercase. The case-insensitive
      flag is scoped to the city name alone — applying it to the ``[A-Z]``
      lookahead would let it match any letter and defeat the purpose.
    """
    found = set()
    for needle in needles:
        escaped = re.escape(needle)
        if re.search(rf"\b{escaped}\b", text, re.IGNORECASE):
            found.add(needle)
        elif re.search(rf"(?i:\b{escaped})(?=[A-Z])", text):
            found.add(needle)
    return found


def coords_are_real(lat: float | None, lng: float | None, geocode_quality: str | None) -> bool:
    """A city-centre fallback is not evidence of location."""
    if lat is None or lng is None:
        return False
    return geocode_quality not in {"city-default", "unlocated", None, ""}


def in_bbox(lat: float, lng: float, bbox: tuple[float, float, float, float]) -> bool:
    min_lat, min_lng, max_lat, max_lng = bbox
    return min_lat <= lat <= max_lat and min_lng <= lng <= max_lng


def city_verdict(
    *,
    title: str,
    location: str = "",
    lat: float | None,
    lng: float | None,
    geocode_quality: str | None,
    city_slugs: list[str],
    bbox: tuple[float, float, float, float],
) -> tuple[bool, str]:
    """Return (keep, reason). `reason` is logged, so make it readable.

    `title` and `location` are deliberately separate, and the title wins.

    The sources fabricate location: CommunityMeetups sets `venue_name` and
    `address` to the literal string "Gurugram" when a listing gives no venue.
    Treating that as evidence created a self-fulfilling filter - "Codex
    Community Meetup - Bengaluru" was kept because *our own default* claimed it
    was in Gurugram. A city named in the title is the organiser's own statement
    about the event; a city appearing in a defaulted venue field is our guess.
    """
    slugs = {slug.lower() for slug in city_slugs}

    if coords_are_real(lat, lng, geocode_quality):
        if in_bbox(lat, lng, bbox):  # type: ignore[arg-type]
            return True, "coordinates inside city bounds"
        return False, f"coordinates {lat:.4f},{lng:.4f} outside city bounds"

    # Case is preserved: the CamelCase check in _mentions depends on it.
    title_other = _mentions(title or "", OTHER_CITIES)
    title_target = _mentions(title or "", slugs)

    if title_other and not title_target:
        return False, f"title names another city ({', '.join(sorted(title_other))})"
    if title_target:
        return True, f"title names the city ({', '.join(sorted(title_target))})"

    loc_other = _mentions(location or "", OTHER_CITIES)
    loc_target = _mentions(location or "", slugs)
    if loc_other and not loc_target:
        return False, f"venue names another city ({', '.join(sorted(loc_other))})"
    if loc_target:
        return True, f"venue names the city ({', '.join(sorted(loc_target))})"

    return True, "no city named; kept by default"
