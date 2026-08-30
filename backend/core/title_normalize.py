from __future__ import annotations

import re
import unicodedata

MONTHS = (
    "january|february|march|april|may|june|july|august|september|october|"
    "november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec"
)

_EDITION_MARKERS = [
    re.compile(r"#\s*\d+", re.I),
    re.compile(r"\bvol\.?\s*\d+\b", re.I),
    re.compile(r"\bvolume\s*\d+\b", re.I),
    re.compile(r"\bedition\s*\d+\b", re.I),
    re.compile(r"\b(?:20\d{2}|19\d{2})\b"),
    re.compile(r"\b\d+(?:st|nd|rd|th)\b", re.I),
    re.compile(rf"\b(?:{MONTHS})\b", re.I),
    re.compile(rf"[—–-]\s*(?:{MONTHS})\s+edition\b", re.I),
    re.compile(rf"\b(?:{MONTHS})\s+edition\b", re.I),
    re.compile(r"\b(?:monthly|weekly|quarterly)\s+edition\b", re.I),
    re.compile(r"\bep(?:isode)?\s*\d+\b", re.I),
    re.compile(r"\bsession\s*\d+\b", re.I),
    re.compile(r"\bseason\s*\d+\b", re.I),
    re.compile(r"\bpart\s*\d+\b", re.I),
]


def normalize_name(value: str) -> str:
    folded = unicodedata.normalize("NFKD", value or "")
    folded = "".join(ch for ch in folded if not unicodedata.combining(ch))
    folded = folded.lower()
    folded = re.sub(r"[^a-z0-9]+", " ", folded)
    return re.sub(r"\s+", " ", folded).strip()


def normalize_title(title: str) -> str:
    """Strip edition markers so monthly recurrences collapse to one series key."""
    text = title or ""
    for pattern in _EDITION_MARKERS:
        text = pattern.sub(" ", text)
    text = re.sub(r"[—–|:]+", " ", text)
    text = re.sub(r"\bedition\b", " ", text, flags=re.I)
    return normalize_name(text)
