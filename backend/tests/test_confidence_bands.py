from core.confidence import confidence_band, should_escalate


def test_boundary_values():
    assert confidence_band(0.49) == "unclear"
    assert confidence_band(0.50) == "possibly"
    assert confidence_band(0.74) == "possibly"
    assert confidence_band(0.75) == "likely"
    assert confidence_band(0.99) == "likely"


def test_none_has_no_band():
    assert confidence_band(None) is None


def test_low_confidence_escalates():
    assert should_escalate(0.49) is True
    assert should_escalate(0.50) is False
