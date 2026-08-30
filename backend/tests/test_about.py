from core.about import compose_about


def test_prefer_verdict_expect():
    assert compose_about("Long listing copy.", "You will build, not listen.") == "You will build, not listen."


def test_falls_back_to_first_sentences():
    about = compose_about("First sentence. Second sentence. Third is dropped.")
    assert about == "First sentence. Second sentence."


def test_empty_when_nothing_sourced():
    assert compose_about("") == ""
    assert compose_about("   ") == ""
