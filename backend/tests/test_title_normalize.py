from core.title_normalize import normalize_title


def test_hash_number():
    assert normalize_title("Claude Meetup #12") == normalize_title("Claude Meetup #13")


def test_volume():
    assert normalize_title("AI Builders Vol. 3") == "ai builders"
    assert normalize_title("AI Builders Volume 4") == "ai builders"


def test_month_edition():
    assert normalize_title("Founders Dinner — December Edition") == "founders dinner"
    assert normalize_title("Founders Dinner January Edition") == "founders dinner"


def test_year():
    assert normalize_title("Product Night 2026") == "product night"


def test_ordinals():
    assert normalize_title("Yoga in the Park 1st") == normalize_title("Yoga in the Park 2nd")


def test_episode_session_season_part():
    assert normalize_title("Community Meetup Episode 4") == "community meetup"
    assert normalize_title("GGN Founders Session 9") == "ggn founders"
    assert normalize_title("Hack Night Season 2") == "hack night"
    assert normalize_title("Python User Group Part 1") == "python user group"


def test_distinct_titles_stay_distinct():
    assert normalize_title("AI Workshop") != normalize_title("AI Workshop for Product Managers")
    assert normalize_title("Claude Meetup") != normalize_title("Claude Workshop")
