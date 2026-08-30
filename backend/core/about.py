from __future__ import annotations

import re


def compose_about(description: str = "", expect: str = "") -> str:
    """Two-to-three sentences from sources we already have. Never invents."""
    expect = (expect or "").strip()
    if expect:
        return expect
    text = re.sub(r"\s+", " ", (description or "").strip())
    if not text:
        return ""
    parts = re.split(r"(?<=[.!?])\s+", text)
    clipped = " ".join(parts[:2]).strip()
    if len(clipped) > 360:
        clipped = clipped[:357].rsplit(" ", 1)[0] + "…"
    return clipped
