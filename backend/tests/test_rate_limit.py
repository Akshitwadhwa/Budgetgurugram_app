from fastapi import HTTPException

from core.qa import questions_over_limit


def test_twentieth_is_allowed_twenty_first_is_not():
    assert questions_over_limit(19, limit=20) is False
    assert questions_over_limit(20, limit=20) is True
    assert questions_over_limit(21, limit=20) is True


def test_enforce_qa_limit_returns_429(monkeypatch):
    from app import deps

    class FakeSession:
        def scalar(self, _stmt):
            return 20

    monkeypatch.setattr(
        deps,
        "get_settings",
        lambda: type("S", (), {"qa_daily_limit": 20})(),
    )
    device = type("D", (), {"id": "abc"})()
    try:
        deps.enforce_qa_limit(device=device, session=FakeSession())
        raised = None
    except HTTPException as exc:
        raised = exc
    assert raised is not None
    assert raised.status_code == 429
    assert "20 questions" in raised.detail
    assert raised.headers["Retry-After"] == "86400"
