"""Regression tests for onboarding audience personalization in recommendations."""

from types import SimpleNamespace

from app.routes.recommendations import _audience_gender_values


def test_menswear_audience_includes_menswear_and_unisex_catalog_labels():
    prefs = SimpleNamespace(preferred_aesthetics=["Audience: Menswear"])
    values = _audience_gender_values(prefs)

    assert "men" in values
    assert "male" in values
    assert "unisex" in values
    assert "women" not in values


def test_womenswear_audience_includes_womenswear_and_unisex_catalog_labels():
    prefs = SimpleNamespace(preferred_aesthetics=["Audience: Womenswear"])
    values = _audience_gender_values(prefs)

    assert "women" in values
    assert "female" in values
    assert "unisex" in values
    assert "men" not in values


def test_both_unisex_and_personalize_later_do_not_narrow_catalog():
    for audience in ("All fashion", "Personalize later"):
        prefs = SimpleNamespace(preferred_aesthetics=[f"Audience: {audience}"])
        assert _audience_gender_values(prefs) == []


def test_legacy_or_missing_preferences_remain_unfiltered():
    assert _audience_gender_values(None) == []
    assert _audience_gender_values(SimpleNamespace(preferred_aesthetics=["Minimalist"])) == []
