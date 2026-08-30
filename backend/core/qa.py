from __future__ import annotations

import re

REFUSAL_MESSAGE = "I don't have enough on this one"
RETRIEVAL_MIN_SIMILARITY_DEFAULT = 0.30


def normalize_question(question: str) -> str:
    text = (question or "").lower().strip()
    text = re.sub(r"[^a-z0-9\s]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def should_refuse(similarities: list[float], min_similarity: float = RETRIEVAL_MIN_SIMILARITY_DEFAULT) -> bool:
    if not similarities:
        return True
    return max(similarities) < min_similarity


def questions_over_limit(count: int, limit: int = 20) -> bool:
    return count >= limit


def strip_ungrounded_citations(citations: list[dict], allowed_urls: set[str]) -> list[dict]:
    cleaned = []
    for item in citations:
        url = item.get("sourceUrl") or item.get("source_url") or ""
        if url in allowed_urls:
            cleaned.append(
                {
                    "sourceUrl": url,
                    "sourceTitle": item.get("sourceTitle") or item.get("source_title") or "",
                    "quote": item.get("quote") or "",
                }
            )
    return cleaned
