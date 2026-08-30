from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from urllib.parse import urlparse

# Typographic variants that mean the same thing. Source pages use curly quotes
# and en/em dashes; models reproduce them as ASCII when quoting. Comparing
# raw strings rejected genuine quotes for punctuation alone - two of every
# three verdicts - so the comparison is normalised on both sides.
_TYPOGRAPHY = str.maketrans({
    "‘": "'", "’": "'", "‚": "'", "‛": "'",
    "“": '"', "”": '"', "„": '"', "‟": '"',
    "–": "-", "—": "-", "―": "-", "−": "-",
    " ": " ", "…": "...", "·": " ",
})


def normalize_for_match(text: str) -> str:
    """Fold typography and whitespace so a real quote is not rejected for punctuation.

    This does not weaken grounding: the words must still appear, in order, in
    the fetched document. It only stops a curly apostrophe from being treated
    as a fabrication.
    """
    folded = unicodedata.normalize("NFKC", text or "").translate(_TYPOGRAPHY)
    return re.sub(r"\s+", " ", folded).strip().casefold()


class EnrichmentRejected(ValueError):
    pass


@dataclass(frozen=True)
class EvidenceItem:
    claim: str
    source_url: str
    source_title: str
    quote: str


@dataclass
class EnrichmentDraft:
    true_format: str
    format_confidence: float
    level: str | None
    hands_on: bool | None
    expect: str
    who_should_come: list[str]
    prep_needed: str | None
    watch_outs: list[str]
    evidence: list[EvidenceItem]


ALLOWED_FORMATS = {
    "workshop",
    "talk",
    "panel",
    "networking",
    "hackathon",
    "demo_day",
    "social",
    "conference",
    "unclear",
}


def parse_draft(payload: dict) -> EnrichmentDraft:
    evidence = [
        EvidenceItem(
            claim=str(item.get("claim") or ""),
            source_url=str(item.get("source_url") or item.get("sourceUrl") or ""),
            source_title=str(item.get("source_title") or item.get("sourceTitle") or ""),
            quote=str(item.get("quote") or ""),
        )
        for item in payload.get("evidence") or []
    ]
    return EnrichmentDraft(
        true_format=str(payload.get("true_format") or payload.get("trueFormat") or "unclear"),
        format_confidence=float(payload.get("format_confidence") or payload.get("confidence") or 0),
        level=payload.get("level"),
        hands_on=payload.get("hands_on") if "hands_on" in payload else payload.get("handsOn"),
        expect=str(payload.get("expect") or ""),
        who_should_come=list(payload.get("who_should_come") or payload.get("whoShouldCome") or []),
        prep_needed=payload.get("prep_needed") if "prep_needed" in payload else payload.get("prepNeeded"),
        watch_outs=list(payload.get("watch_outs") or payload.get("watchOuts") or []),
        evidence=evidence,
    )


def validate_enrichment(
    draft: EnrichmentDraft,
    allowed_urls: set[str],
    source_texts: dict[str, str],
) -> EnrichmentDraft:
    """Write-time grounding. A cited URL we never fetched is a hallucination."""
    if not draft.evidence:
        raise EnrichmentRejected("evidence must be non-empty")
    if draft.true_format not in ALLOWED_FORMATS:
        raise EnrichmentRejected(f"unknown format {draft.true_format}")
    if not 0 <= draft.format_confidence <= 1:
        raise EnrichmentRejected("format_confidence must be between 0 and 1")
    if not draft.expect.strip():
        raise EnrichmentRejected("expect is required")

    for item in draft.evidence:
        if not item.source_url:
            raise EnrichmentRejected("evidence item missing source_url")
        # A citation the reader cannot open is not a citation. This caught real
        # verdicts citing a bare Luma slug ("i7tjwimu") as their source, which
        # the app would have rendered as a tappable link leading nowhere -
        # exactly the unverifiable claim the evidence rule exists to prevent.
        parsed = urlparse(item.source_url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise EnrichmentRejected(f"source_url is not a usable URL: {item.source_url}")
        if item.source_url not in allowed_urls:
            raise EnrichmentRejected(f"cited URL was never fetched: {item.source_url}")
        body = source_texts.get(item.source_url) or ""
        if item.quote and normalize_for_match(item.quote) not in normalize_for_match(body):
            raise EnrichmentRejected("quote is not a substring of its source document")

    return _cap_confidence_to_evidence(draft)


# The band at which the UI starts making assertive statements ("Likely a
# workshop"). Below it the copy stays visibly tentative.
ASSERTIVE_BAND = 0.75

# What each level of corroboration is allowed to buy. A verdict inferred from
# a handful of web pages is never near-certain, however sure the model sounds:
# one run produced 0.98, which no amount of scraping justifies.
CONFIDENCE_CEILINGS = {1: 0.74, 2: 0.85}
MAX_CONFIDENCE = 0.92


# Hosts that serve the same page under different names. Counting an alias pair
# as two sources let a single page corroborate itself: one verdict cited both
# luma.com/163ezlvu and lu.ma/163ezlvu and was scored as independently
# confirmed.
_HOST_ALIASES = {"lu.ma": "luma.com", "www.luma.com": "luma.com"}


def canonical_source_key(url: str) -> str:
    """Identify the underlying page, ignoring scheme, www, aliases and slashes."""
    parsed = urlparse(url or "")
    host = (parsed.netloc or "").lower().removeprefix("www.")
    host = _HOST_ALIASES.get(host, host)
    path = (parsed.path or "").rstrip("/").lower()
    return f"{host}{path}"


def _cap_confidence_to_evidence(draft: EnrichmentDraft) -> EnrichmentDraft:
    """Stop the model asserting more than its sources support.

    Confidence is self-reported, and it shows: listing-only verdicts came back
    at exactly 0.78 every time, which is a habit rather than a measurement.
    0.78 lands in the assertive band, so the app was stating "Likely a social"
    on the strength of one page that had never been corroborated by anything.

    A single source cannot corroborate itself - least of all the event's own
    listing, which is the very thing this product exists to check. So one
    distinct source caps the verdict below the assertive band. Two independent
    sources that agree is the bar for speaking confidently.
    """
    distinct = len({canonical_source_key(item.source_url) for item in draft.evidence})
    ceiling = CONFIDENCE_CEILINGS.get(distinct, MAX_CONFIDENCE)
    if draft.format_confidence > ceiling:
        draft.format_confidence = ceiling
    return draft
