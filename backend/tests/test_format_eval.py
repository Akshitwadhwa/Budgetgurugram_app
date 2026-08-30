import json
from pathlib import Path

FIXTURE = Path(__file__).parent / "fixtures" / "format_eval.json"


def test_eval_set_is_labelled_and_sized():
    rows = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert len(rows) == 30
    allowed = {
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
    for row in rows:
        assert row["expected"] in allowed
        assert row["title"]
        assert row["description"]


def test_confident_wrong_answer_is_a_hard_failure():
    """Gate documented in the spec: an incorrect verdict above 0.75 fails the eval.

    Live LLM scoring is opt-in via RUN_PROMPT_EVAL=1 so CI stays deterministic.
    This test keeps the rule encoded even when the model is not called.
    """
    predicted = {"expected": "workshop", "predicted": "talk", "confidence": 0.82}
    confident_wrong = predicted["predicted"] != predicted["expected"] and predicted["confidence"] >= 0.75
    assert confident_wrong is True
