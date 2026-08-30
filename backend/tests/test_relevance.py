from core.relevance import is_about_event

EVENT_URL = "https://luma.com/k5m6gl5o"
TITLE = "Integration vs. Independence: What is the Optimal GTM and Tech Stack Strategy for Post-Acquisition Success?"


def check(doc_url, doc_text, title=TITLE, organizer_name=None, organizer_url=None):
    return is_about_event(
        doc_url=doc_url,
        doc_text=doc_text,
        event_url=EVENT_URL,
        event_title=title,
        organizer_name=organizer_name,
        organizer_url=organizer_url,
    )


class TestTopicMatchesAreRejected:
    """The failure this module exists to prevent.

    These pages were really fetched and really cited. Every grounding check
    passed - the URL was fetched, the quote was a genuine substring - and the
    evidence was still about a different subject entirely.
    """

    def test_consulting_article_on_the_same_topic_is_rejected(self):
        citable, reason = check(
            "https://nortal.com/insights/post-merger-tech-integration-challenges",
            "Merging tech stacks after M&A? A practical guide for tech leaders. "
            "Post-merger integration requires a clear strategy for the combined "
            "technology organisation and go-to-market team.",
        )
        assert not citable
        assert "topic-only" in reason

    def test_generic_best_practices_page_is_rejected(self):
        citable, _ = check(
            "https://imaa-institute.org/blog/post-merger-and-acquisition-integration-best-practices/",
            "Proven best practices to achieve post M&A success. Integration "
            "strategy, technology stack alignment and growth planning.",
        )
        assert not citable

    def test_city_events_directory_is_rejected(self):
        citable, _ = check(
            "https://www.meetup.com/find/in--gurgaon/",
            "Events in Gurgaon. Find events in Gurgaon to connect with people "
            "who share your interests. Startup, tech and community meetups.",
        )
        assert not citable


class TestIdentityQualifies:
    def test_the_listing_itself(self):
        citable, reason = check(EVENT_URL, "anything at all")
        assert citable
        assert "own listing" in reason

    def test_trailing_slash_does_not_break_the_match(self):
        citable, _ = check(EVENT_URL + "/", "anything")
        assert citable

    def test_organiser_domain(self):
        citable, reason = check(
            "https://aihouse.example/about",
            "unrelated copy",
            organizer_url="https://www.aihouse.example/",
        )
        assert citable
        assert "organiser's domain" in reason

    def test_page_naming_the_organiser(self):
        citable, reason = check(
            "https://someblog.example/recap",
            "Last week CommunityMeetups ran another packed evening in the city.",
            organizer_name="CommunityMeetups",
        )
        assert citable
        assert "names the organiser" in reason

    def test_page_quoting_the_title(self):
        citable, reason = check(
            "https://internshala.example/competitions/xyz",
            "Register now for Integration vs Independence: what is the optimal "
            "GTM and tech stack strategy for post-acquisition success?",
        )
        assert citable
        assert "quotes the title" in reason


class TestShortTitles:
    def test_short_title_needs_the_whole_thing(self):
        citable, _ = check(
            "https://blog.example/x",
            "A write-up of the chai charchaa evening in sector 29.",
            title="Chai Charchaa",
        )
        assert citable

    def test_short_title_absent_is_rejected(self):
        citable, _ = check(
            "https://blog.example/x",
            "An unrelated article about coffee culture.",
            title="Chai Charchaa",
        )
        assert not citable
