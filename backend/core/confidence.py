"""Server-side confidence bands. The app never reimplements these thresholds."""

LIKELY = 0.75
POSSIBLY = 0.50


def confidence_band(confidence: float | None) -> str | None:
    if confidence is None:
        return None
    if confidence >= LIKELY:
        return "likely"
    if confidence >= POSSIBLY:
        return "possibly"
    return "unclear"


def should_escalate(confidence: float) -> bool:
    return confidence < POSSIBLY
