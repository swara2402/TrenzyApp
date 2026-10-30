from app.routes.persona import _STYLE_PERSONAS, _match_persona_from_preferences


def test_each_style_preference_selects_its_matching_persona():
    cases = {
        "clean girl": "Urban Minimalist",
        "experimental": "Avant-Garde Explorer",
        "coquette": "Bohemian Spirit",
        "streetwear": "Streetwear Icon",
        "tailored": "Classic Elegance",
        "sustainable": "Eco-Conscious Curator",
    }

    for style, expected_name in cases.items():
        index = _match_persona_from_preferences({"preferred_styles": [style]})
        assert _STYLE_PERSONAS[index]["name"] == expected_name


def test_persona_selection_is_stable_for_unchanged_preferences():
    preferences = {
        "preferred_styles": ["streetwear", "oversized"],
        "preferred_colors": ["Black"],
        "preferred_categories": ["Footwear"],
    }

    first = _match_persona_from_preferences(preferences)
    second = _match_persona_from_preferences(preferences)

    assert first == second
