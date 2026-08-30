from unittest.mock import MagicMock, patch

from core.qa import REFUSAL_MESSAGE, normalize_question, should_refuse, strip_ungrounded_citations


def test_empty_retrieval_refuses():
    assert should_refuse([]) is True


def test_low_similarity_refuses():
    assert should_refuse([0.12, 0.20], min_similarity=0.30) is True


def test_strong_hit_does_not_refuse():
    assert should_refuse([0.12, 0.81], min_similarity=0.30) is False


def test_question_normalization():
    assert normalize_question("Is this beginner-friendly?") == "is this beginner friendly"


def test_ungrounded_citations_stripped():
    cleaned = strip_ungrounded_citations(
        [{"source_url": "https://ok.example", "source_title": "Ok", "quote": "hi"}],
        {"https://ok.example"},
    )
    assert cleaned == [{"sourceUrl": "https://ok.example", "sourceTitle": "Ok", "quote": "hi"}]
    assert strip_ungrounded_citations(
        [{"source_url": "https://nope.example", "quote": "x"}],
        {"https://ok.example"},
    ) == []


def test_empty_retrieval_never_calls_llm():
    from app.routers import ask as ask_mod

    event = MagicMock()
    event.id = "evt"
    event.series_id = None
    event.organizer_id = None
    event.title = "Night"
    event.url = "https://lu.ma/x"
    event.description_raw = ""

    session = MagicMock()
    session.get.return_value = event
    session.scalar.return_value = None
    session.scalars.return_value.all.return_value = []

    device = MagicMock()
    device.id = "device-1"

    body = ask_mod.AskRequest(question="Is this a workshop?")

    with (
        patch.object(ask_mod, "embed_one", side_effect=AssertionError("embed should not be needed after empty chunks")),
        patch.object(ask_mod, "complete_structured") as complete,
    ):
        # empty chunks → ranked stays empty → refuse before LLM
        session.scalars.return_value.all.return_value = []
        with patch.object(ask_mod, "embed_one", side_effect=ask_mod.LlmError("no key")):
            response = ask_mod.ask_event(event_id="evt", body=body, device=device, session=session)

    complete.assert_not_called()
    assert response.refused is True
    assert response.answer == REFUSAL_MESSAGE
