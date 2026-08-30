from __future__ import annotations

from dataclasses import dataclass


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
        if item.source_url not in allowed_urls:
            raise EnrichmentRejected(f"cited URL was never fetched: {item.source_url}")
        body = source_texts.get(item.source_url) or ""
        if item.quote and item.quote not in body:
            raise EnrichmentRejected("quote is not a substring of its source document")
    return draft
