import json
from pathlib import Path

from core.title_normalize import normalize_title
from worker.series_match import SeriesCandidate, decide_match, keys_match

FIXTURE = Path(__file__).parent / "fixtures" / "series_golden.json"


def test_golden_title_pairs_do_not_merge_distinct_series():
    pairs = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert len(pairs) >= 40
    failures = []
    for pair in pairs:
        matched = keys_match(pair["a"], pair["b"])
        if matched != pair["same"]:
            failures.append(
                f"{pair['a']!r} vs {pair['b']!r}: expected same={pair['same']} "
                f"got keys {normalize_title(pair['a'])!r} / {normalize_title(pair['b'])!r}"
            )
    assert not failures, "\n".join(failures)


def test_decide_match_single_strong_candidate_is_free():
    decision = decide_match(
        [SeriesCandidate("s1", "Claude Meetup", "claude meetup", trigram=0.92, cosine=0.04)]
    )
    assert decision == "match:s1"


def test_decide_match_zero_candidates_creates_series():
    assert decide_match([]) == "new"


def test_decide_match_ambiguous_uses_llm():
    decision = decide_match(
        [SeriesCandidate("s1", "AI Night", "ai night", trigram=0.66, cosine=0.12)]
    )
    assert decision == "llm"


def test_decide_match_two_strong_candidates_uses_llm():
    decision = decide_match(
        [
            SeriesCandidate("s1", "AI Night", "ai night", trigram=0.9, cosine=0.05),
            SeriesCandidate("s2", "AI Nights", "ai nights", trigram=0.88, cosine=0.06),
        ]
    )
    assert decision == "llm"
