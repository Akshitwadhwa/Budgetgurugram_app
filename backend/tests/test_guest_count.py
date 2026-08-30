from core.guest_count import extract_guest_count


def test_luma_guest_count():
    assert extract_guest_count({"guest_count": 47}) == 47


def test_nested_event_object():
    assert extract_guest_count({"event": {"guest_count": 12}}) == 12


def test_guest_counts_going():
    assert extract_guest_count({"guest_counts": {"going": 9, "waitlist": 40}}) == 9


def test_ignores_capacity_and_zero():
    assert extract_guest_count({"maximumAttendeeCapacity": 200}) is None
    assert extract_guest_count({"guest_count": 0}) is None


def test_meetup_attendee_list():
    assert extract_guest_count({"attendee": [{"name": "A"}, {"name": "B"}]}) == 2


def test_empty_raw():
    assert extract_guest_count({}) is None
    assert extract_guest_count(None) is None
