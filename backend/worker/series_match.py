from __future__ import annotations

from dataclasses import dataclass

from core.title_normalize import normalize_title

HIGH_TRIGRAM = 0.85
LOW_TRIGRAM = 0.60
HIGH_COSINE = 0.08
LOW_COSINE = 0.15


@dataclass
class SeriesCandidate:
    series_id: str
    canonical_title: str
    normalized_key: str
    trigram: float
    cosine: float | None


def decide_match(candidates: list[SeriesCandidate]) -> str:
    """Return 'match:<id>', 'new', or 'llm'. The LLM is a tiebreaker, not a matcher."""
    if not candidates:
        return "new"
    strong = [
        item
        for item in candidates
        if item.trigram >= HIGH_TRIGRAM or (item.cosine is not None and item.cosine < HIGH_COSINE)
    ]
    if len(strong) == 1:
        return f"match:{strong[0].series_id}"
    if len(strong) > 1:
        return "llm"
    ambiguous = [
        item
        for item in candidates
        if item.trigram >= LOW_TRIGRAM or (item.cosine is not None and item.cosine < LOW_COSINE)
    ]
    if ambiguous:
        return "llm"
    return "new"


def keys_match(title_a: str, title_b: str) -> bool:
    key = normalize_title(title_a)
    return bool(key) and key == normalize_title(title_b)
