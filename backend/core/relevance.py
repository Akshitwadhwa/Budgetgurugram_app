"""Decide whether a fetched page is about *this event* — not merely its topic.

The distinction matters more than it sounds. Web search on
"Integration vs. Independence: ... Post-Acquisition Success? Gurugram" returns
consulting articles about post-merger integration. Those pages are real, the
quotes pulled from them are real, and the grounding validator cannot object:
the URL was fetched and the quote is a genuine substring.

The result is a verdict about a Gurugram meetup supported by a citation from a
management-consultancy blog that has never heard of it. Every individual check
passes and the conclusion is still worthless — which is exactly what
"hallucinated" feels like to a reader.

Shared vocabulary is therefore not enough. A page earns the right to be cited
only by referring to the event or its organiser *specifically*.
"""

from __future__ import annotations

import re

# Words that carry no identifying power in an event title.
GENERIC = {
    "the", "and", "for", "with", "vol", "part", "meet", "meetup", "event",
    "events", "group", "club", "session", "edition", "first", "new", "your",
    "our", "off", "record", "live", "night", "day", "week", "month", "free",
    "what", "how", "why", "who", "should", "they", "from", "into", "your",
    "startup", "startups", "founder", "founders", "tech", "ai", "build",
    "building", "growth", "strategy", "success", "team", "teams", "best",
    "guide", "top", "india", "indian", "online", "register", "join", "ticket",
    "tickets", "community", "workshop", "conference", "summit", "hackathon",
}


def _norm(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", (text or "").lower())


def _significant(text: str) -> list[str]:
    return [w for w in _norm(text).split() if len(w) > 3 and w not in GENERIC]


def _host(url: str) -> str:
    match = re.match(r"https?://([^/]+)", url or "", re.IGNORECASE)
    return match.group(1).lower().removeprefix("www.") if match else ""


def is_about_event(
    *,
    doc_url: str,
    doc_text: str,
    event_url: str,
    event_title: str,
    organizer_name: str | None = None,
    organizer_url: str | None = None,
) -> tuple[bool, str]:
    """Return (citable, reason).

    A page qualifies on identity, never on topic:

    * it *is* the event's own listing;
    * it is on the organiser's domain;
    * it names the organiser; or
    * it reproduces a distinctive run of the event's title.

    Topical similarity deliberately does not qualify.
    """
    if doc_url and event_url and doc_url.rstrip("/") == event_url.rstrip("/"):
        return True, "the event's own listing"

    doc_host = _host(doc_url)
    org_host = _host(organizer_url or "")
    if doc_host and org_host and doc_host == org_host:
        return True, f"organiser's domain ({doc_host})"

    haystack = _norm(doc_text)

    if organizer_name:
        org_norm = _norm(organizer_name).strip()
        if len(org_norm) > 4 and org_norm in haystack:
            return True, f"names the organiser ({organizer_name})"

    # A distinctive phrase from the title, not a bag of shared words. Three
    # consecutive significant words is specific enough that a generic article
    # on the same subject will not contain it.
    #
    # Both sides are reduced to their significant words before comparing.
    # Comparing filtered title phrases against raw document text fails on any
    # page that reproduces the title faithfully, because the filler words the
    # title filter removed ("vs", "the", "and") are still sitting between the
    # words in the document.
    words = _significant(event_title)
    doc_words = " ".join(_significant(doc_text))
    if len(words) >= 3:
        for i in range(len(words) - 2):
            phrase = " ".join(words[i : i + 3])
            if phrase in doc_words:
                return True, f"quotes the title ({phrase!r})"
    elif words and " ".join(words) in doc_words:
        # Short titles have no 3-word window; require the whole thing.
        return True, "contains the full title"

    return False, "topic-only match; does not mention this event or organiser"
