from core.city_filter import city_verdict

SLUGS = ["gurugram", "gurgaon"]
BBOX = (28.35, 76.92, 28.56, 77.16)


def verdict(text="", location="", lat=None, lng=None, quality=None):
    return city_verdict(
        title=text,
        location=location,
        lat=lat,
        lng=lng,
        geocode_quality=quality,
        city_slugs=SLUGS,
        bbox=BBOX,
    )


class TestRealCoordinatesDecide:
    def test_inside_bbox_is_kept(self):
        keep, _ = verdict(text="Somewhere", lat=28.49, lng=77.08, quality="exact")
        assert keep

    def test_outside_bbox_is_rejected_even_if_text_says_gurugram(self):
        # Bengaluru coordinates. Coordinates outrank a possibly-copied title.
        keep, reason = verdict(text="Gurugram chapter", lat=12.97, lng=77.59, quality="exact")
        assert not keep
        assert "outside city bounds" in reason

    def test_city_default_coordinates_are_not_trusted(self):
        # Every out-of-town event carries the Gurugram centre as a fallback, so
        # honouring these would accept the entire country.
        keep, _ = verdict(text="Bengaluru summit", lat=28.4945, lng=77.0894, quality="city-default")
        assert not keep


class TestNamedCities:
    def test_rival_city_in_title_is_rejected(self):
        # The exact events that reached paid enrichment before this existed.
        for title in (
            "Codex Community Meetup - Bengaluru",
            "Founders Running Club :: Mumbai",
            "Resurgence of Mumbai Startup Ecosystem.",
            "Bengaluru 2026 Venture Capital World Summit",
            "NagpurStartups Meetup",
            "Claude Workshop | ADHD Hacks | Bangalore",
        ):
            keep, reason = verdict(text=title)
            assert not keep, f"should have rejected {title!r}"
            assert "names another city" in reason

    def test_target_city_wins_when_both_named(self):
        keep, _ = verdict(text="Bengaluru founders visit Gurugram")
        assert keep

    def test_gurgaon_spelling_is_accepted(self):
        keep, _ = verdict(text="Elite Star Couples & Families of Gurgaon")
        assert keep

    def test_substring_does_not_false_match(self):
        # "Surat" must not match inside "Suratgarh".
        keep, _ = verdict(text="Suratgarh community meet")
        assert keep


class TestDefault:
    def test_unnamed_location_is_kept(self):
        # Rejecting these would empty the app: most local listings never say
        # which city they are in.
        keep, reason = verdict(text="Chai Pe Charchaa")
        assert keep
        assert "kept by default" in reason

    def test_empty_text_is_kept(self):
        keep, _ = verdict(text="")
        assert keep


class TestFabricatedVenueIsNotEvidence:
    """The sources default venue_name/address to the literal target city.

    Trusting that made the filter self-fulfilling: every out-of-city event
    carried "Gurugram" in a field we had invented, which cancelled out the real
    city named in its own title.
    """

    def test_title_beats_a_defaulted_venue(self):
        keep, reason = verdict(
            text="Codex Community Meetup - Bengaluru",
            location="Gurugram Gurugram",
        )
        assert not keep
        assert "title names another city" in reason

    def test_all_the_events_that_slipped_through(self):
        for title in (
            "Codex Community Meetup - Bengaluru",
            "Founders Running Club :: Surat",
            "Founders Running Club :: Mumbai",
            "Founders Running Club :: Bengaluru",
            "Claude Workshop | ADHD Hacks | Bangalore",
            "Resurgence of Mumbai Startup Ecosystem.",
            "Bengaluru 2026 Venture Capital World Summit",
            "NagpurStartups Meetup",
        ):
            keep, _ = verdict(text=title, location="Gurugram Gurugram")
            assert not keep, f"should have rejected {title!r}"

    def test_real_venue_still_rejects(self):
        keep, reason = verdict(text="Founders Mixer", location="HSR Layout, Bengaluru")
        assert not keep
        assert "venue names another city" in reason

    def test_local_event_with_defaulted_venue_is_kept(self):
        keep, _ = verdict(text="Chai Pe Charchaa", location="Gurugram Gurugram")
        assert keep
