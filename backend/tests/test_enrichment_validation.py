import pytest

from core.enrichment import EnrichmentDraft, EnrichmentRejected, EvidenceItem, validate_enrichment


def _draft(**overrides) -> EnrichmentDraft:
    base = EnrichmentDraft(
        true_format="workshop",
        format_confidence=0.82,
        level="intermediate",
        hands_on=True,
        expect="You will build, not just listen.",
        who_should_come=["builders"],
        prep_needed="Laptop",
        watch_outs=[],
        evidence=[
            EvidenceItem(
                claim="Last edition was hands-on",
                source_url="https://example.com/recap",
                source_title="Recap",
                quote="everyone shipped a prototype",
            )
        ],
    )
    for key, value in overrides.items():
        setattr(base, key, value)
    return base


ALLOWED = {"https://example.com/recap"}
TEXTS = {"https://example.com/recap": "Last month everyone shipped a prototype before dinner."}


def test_empty_evidence_is_rejected():
    with pytest.raises(EnrichmentRejected, match="non-empty"):
        validate_enrichment(_draft(evidence=[]), ALLOWED, TEXTS)


def test_citation_must_have_been_fetched():
    draft = _draft(
        evidence=[
            EvidenceItem(
                claim="x",
                source_url="https://hallucinated.example/page",
                source_title="Nope",
                quote="everyone shipped a prototype",
            )
        ]
    )
    with pytest.raises(EnrichmentRejected, match="never fetched"):
        validate_enrichment(draft, ALLOWED, TEXTS)


def test_quote_must_be_substring():
    draft = _draft(
        evidence=[
            EvidenceItem(
                claim="x",
                source_url="https://example.com/recap",
                source_title="Recap",
                quote="this sentence is not in the document",
            )
        ]
    )
    with pytest.raises(EnrichmentRejected, match="substring"):
        validate_enrichment(draft, ALLOWED, TEXTS)


def test_valid_enrichment_passes():
    assert validate_enrichment(_draft(), ALLOWED, TEXTS).true_format == "workshop"
