from core.geo import classify_geocode, is_gurugram_event


def test_city_default_has_no_fabricated_coords():
    lat, lng, quality = classify_geocode(None, None, "Location listed on Luma", "Gurugram")
    assert quality == "city-default"
    assert lat is None
    assert lng is None


def test_unlocated_has_no_coords():
    lat, lng, quality = classify_geocode(None, None, "", "Unknown")
    assert quality == "unlocated"
    assert lat is None
    assert lng is None


def test_exact_keeps_source_coords_in_bounds():
    lat, lng, quality = classify_geocode(28.4952, 77.0894, "Cyber Hub", "Gurugram")
    assert quality == "exact"
    assert lat == 28.4952


def test_rejects_foreign_city():
    assert (
        is_gurugram_event(
            title="Seoul Startup Night",
            description="Meet founders in Seoul",
            location="Gangnam",
            city="Seoul",
        )
        is False
    )


def test_accepts_gurugram_city():
    assert is_gurugram_event(title="Founders Dinner", city="Gurugram") is True
