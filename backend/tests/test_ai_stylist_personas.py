from app.ai.stylist.fashion_stylist import FashionStylistAgent


def test_stylist_personas_have_distinct_greeting_and_style_focus():
    agent = FashionStylistAgent()

    everyday = agent._fallback_response("hey", [], persona="everyday")
    minimalist = agent._fallback_response("hey", [], persona="minimalist")
    streetwear = agent._fallback_response("hey", [], persona="streetwear")
    trendsetter = agent._fallback_response("hey", [], persona="trendsetter")

    assert len({everyday, minimalist, streetwear, trendsetter}) == 4
    assert "neutral palettes" in minimalist
    assert "sneaker-led looks" in streetwear
    assert "standout pieces" in trendsetter


def test_stylist_persona_defaults_to_everyday():
    agent = FashionStylistAgent()

    response = agent._fallback_response("hello", [])

    assert "friendly everyday stylist" in response
