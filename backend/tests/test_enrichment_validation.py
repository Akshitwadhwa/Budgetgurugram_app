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


def test_non_url_source_is_rejected():
    """A citation the reader cannot open is not a citation.

    Real verdicts cited a bare Luma slug ("i7tjwimu") because the event row
    itself stored a slug instead of a URL, and it was added to the allowed set
    unchecked. The app would have rendered that as a tappable dead link.
    """
    slug = "i7tjwimu"
    draft = _draft(
        evidence=[
            EvidenceItem(
                claim="x",
                source_url=slug,
                source_title="Listing",
                quote="everyone shipped a prototype",
            )
        ]
    )
    with pytest.raises(EnrichmentRejected, match="not a usable URL"):
        validate_enrichment(draft, ALLOWED | {slug}, {**TEXTS, slug: "everyone shipped a prototype"})


class TestConfidenceIsCappedByEvidence:
    """Confidence is self-reported and was demonstrably uncalibrated.

    Every listing-only verdict came back at exactly 0.78 - inside the band
    where the UI says "Likely a workshop" rather than "Possibly". One source
    cannot corroborate itself, so it must not buy an assertive claim.
    """

    def test_single_source_cannot_reach_the_assertive_band(self):
        draft = validate_enrichment(_draft(format_confidence=0.78), ALLOWED, TEXTS)
        assert draft.format_confidence < 0.75

    def test_the_observed_078_is_capped(self):
        draft = validate_enrichment(_draft(format_confidence=0.78), ALLOWED, TEXTS)
        assert draft.format_confidence == 0.74

    def test_low_confidence_is_left_alone(self):
        draft = validate_enrichment(_draft(format_confidence=0.31), ALLOWED, TEXTS)
        assert draft.format_confidence == 0.31

    def test_two_independent_sources_may_be_assertive(self):
        allowed = ALLOWED | {"https://example.com/second"}
        texts = {**TEXTS, "https://example.com/second": "the room was hands on throughout"}
        draft = _draft(
            format_confidence=0.88,
            evidence=[
                EvidenceItem(
                    claim="a",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="everyone shipped a prototype",
                ),
                EvidenceItem(
                    claim="b",
                    source_url="https://example.com/second",
                    source_title="Second",
                    quote="the room was hands on throughout",
                ),
            ],
        )
        # Two sources buy the assertive band, but not near-certainty.
        assert validate_enrichment(draft, allowed, texts).format_confidence == 0.85

    def test_two_citations_of_the_same_page_are_still_one_source(self):
        draft = _draft(
            format_confidence=0.9,
            evidence=[
                EvidenceItem(
                    claim="a",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="everyone shipped a prototype",
                ),
                EvidenceItem(
                    claim="b",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="before dinner",
                ),
            ],
        )
        assert validate_enrichment(draft, ALLOWED, TEXTS).format_confidence == 0.74


class TestQuoteNormalisation:
    """Source pages use curly quotes and em dashes; models type ASCII.

    Comparing raw strings rejected two of every three verdicts over punctuation
    alone. Grounding is unchanged - the words must still be in the document.
    """

    def test_curly_apostrophe_and_em_dash_still_match(self):
        doc = "Bring your laptop — we’ll be building together for most of it."
        draft = _draft(
            evidence=[
                EvidenceItem(
                    claim="hands-on",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="Bring your laptop - we'll be building together",
                )
            ]
        )
        assert validate_enrichment(draft, ALLOWED, {"https://example.com/recap": doc})

    def test_whitespace_differences_still_match(self):
        doc = "the room   was\thands on   throughout"
        draft = _draft(
            evidence=[
                EvidenceItem(
                    claim="x",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="the room was hands on throughout",
                )
            ]
        )
        assert validate_enrichment(draft, ALLOWED, {"https://example.com/recap": doc})

    def test_genuinely_invented_text_is_still_rejected(self):
        # The guarantee that matters: normalisation must not let fabrication through.
        draft = _draft(
            evidence=[
                EvidenceItem(
                    claim="x",
                    source_url="https://example.com/recap",
                    source_title="Recap",
                    quote="attendance was capped at forty people",
                )
            ]
        )
        with pytest.raises(EnrichmentRejected, match="substring"):
            validate_enrichment(draft, ALLOWED, TEXTS)


class TestNearCertaintyIsRefused:
    def test_098_is_capped_even_with_many_sources(self):
        allowed = ALLOWED | {f"https://example.com/s{i}" for i in range(4)}
        texts = {**TEXTS, **{f"https://example.com/s{i}": "shared body text" for i in range(4)}}
        draft = _draft(
            format_confidence=0.98,
            evidence=[
                EvidenceItem(
                    claim=f"c{i}",
                    source_url=f"https://example.com/s{i}",
                    source_title="S",
                    quote="shared body text",
                )
                for i in range(4)
            ],
        )
        assert validate_enrichment(draft, allowed, texts).format_confidence == 0.92


class TestAliasedSourcesAreOneSource:
    """lu.ma and luma.com serve the same page.

    A verdict cited both forms of one listing and was scored as independently
    corroborated, which is how a single page ended up buying the assertive band.
    """

    def test_luma_aliases_collapse(self):
        from core.enrichment import canonical_source_key as key

        assert key("https://lu.ma/163ezlvu") == key("https://luma.com/163ezlvu")
        assert key("https://luma.com/163ezlvu/") == key("http://www.luma.com/163ezlvu")

    def test_distinct_pages_stay_distinct(self):
        from core.enrichment import canonical_source_key as key

        assert key("https://luma.com/aaa") != key("https://luma.com/bbb")
        assert key("https://a.example/x") != key("https://b.example/x")

    def test_alias_pair_does_not_buy_the_assertive_band(self):
        allowed = {"https://lu.ma/x", "https://luma.com/x"}
        texts = {u: "a full day of building" for u in allowed}
        draft = _draft(
            format_confidence=0.85,
            evidence=[
                EvidenceItem(claim="a", source_url="https://lu.ma/x", source_title="L", quote="a full day of building"),
                EvidenceItem(claim="b", source_url="https://luma.com/x", source_title="L", quote="a full day of building"),
            ],
        )
        assert validate_enrichment(draft, allowed, texts).format_confidence == 0.74
