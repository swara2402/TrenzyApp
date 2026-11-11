"""Focused tests for explainable product recommendations and owned-closet styling."""

from types import SimpleNamespace

from app.ai.stylist.fashion_stylist import FashionStylistAgent, _selected_wardrobe_ids
from app.models import WardrobeItem
from app.routes.recommendations import _product_reason


def test_reason_uses_only_matching_onboarding_preferences():
    prefs = SimpleNamespace(
        preferred_styles=["Streetwear"],
        preferred_colors=["Black"],
        preferred_categories=["Tops"],
        preferred_brands=["Example"],
        budget_max=2000,
    )
    product = SimpleNamespace(
        style="Streetwear",
        style_tags=["Relaxed"],
        color="Jet Black",
        category="Tops",
        brand="Example",
        price=1499,
        subcategory="T-shirts",
        tags=["oversized"],
    )

    reason = _product_reason(prefs, product)

    assert "your Streetwear style" in reason
    assert "your preference for Black" in reason
    assert "the Tops category you selected" in reason
    assert "a brand you prefer (Example)" in reason
    assert "within your ₹2,000 budget" in reason


def test_reason_is_empty_when_no_real_signal_matches():
    prefs = SimpleNamespace(
        preferred_styles=["Boho"],
        preferred_colors=["Pink"],
        preferred_categories=["Dresses"],
        preferred_brands=["Other"],
        budget_max=500,
    )
    product = SimpleNamespace(
        style="Formal",
        style_tags=["Classic"],
        color="Navy",
        category="Tops",
        brand="Example",
        price=1200,
        subcategory="Shirt",
        tags=[],
    )

    assert _product_reason(prefs, product) == ""


def test_reason_can_explain_persona_and_positive_behavior():
    persona = SimpleNamespace(keywords=["minimalist"])
    product = SimpleNamespace(
        style="Clean",
        style_tags=["minimalist"],
        color="White",
        category="Tops",
        brand="Example",
        price=900,
        subcategory="Shirt",
        tags=[],
    )

    reason = _product_reason(None, product, persona=persona, signal={
        "styles": ["Clean"],
        "categories": ["Tops"],
        "colors": ["White"],
    })

    assert "your minimalist persona" in reason
    assert "the Tops category you have liked" in reason


def test_stylist_builds_outfit_from_owned_wardrobe_items():
    agent = FashionStylistAgent()
    items = [
        WardrobeItem(name="Black tee", category="Tops", color="Black"),
        WardrobeItem(name="Blue jeans", category="Bottoms", color="Blue"),
        WardrobeItem(name="White sneakers", category="Shoes", color="White"),
        WardrobeItem(name="Silver hoops", category="Jewellery", color="Silver"),
    ]

    response = agent._fallback_response(
        "Style me. Styling brief: occasion=College; aesthetic=Streetwear. "
        "Owned wardrobe pieces: Black tee; Blue jeans; White sneakers; Silver hoops.",
        [],
        persona="streetwear",
        wardrobe_items=items,
    )

    assert "Streetwear look for College" in response
    assert "Black tee" in response
    assert "Blue jeans" in response
    assert "White sneakers" in response
    assert "Silver hoops" in response



def test_stylist_parses_stable_selected_wardrobe_ids():
    message = (
        "Styling brief: occasion=College; aesthetic=Streetwear. "
        "Owned wardrobe item ids: 12, 27, 31. "
        "Owned wardrobe pieces: Black tee; Blue jeans."
    )

    assert _selected_wardrobe_ids(message) == {12, 27, 31}


def test_stylist_returns_no_selected_ids_for_empty_or_legacy_brief():
    assert _selected_wardrobe_ids("No owned wardrobe pieces are selected.") == set()
    assert _selected_wardrobe_ids("Owned wardrobe pieces: Black tee; Blue jeans.") == set()



def test_stylist_uses_aesthetic_palette_when_choosing_owned_pieces():
    agent = FashionStylistAgent()
    items = [
        WardrobeItem(id=1, name="Pink top", category="Tops", color="Pink"),
        WardrobeItem(id=2, name="Black top", category="Tops", color="Black"),
        WardrobeItem(id=3, name="Beige trousers", category="Bottoms", color="Beige"),
    ]

    response = agent._fallback_response(
        "Build me an outfit. Styling brief: occasion=College; aesthetic=Minimal. "
        "Owned wardrobe pieces: Pink top; Black top; Beige trousers.",
        [],
        wardrobe_items=items,
    )

    assert "Black top" in response
    assert "Pink top" not in response
    assert "Beige trousers" in response


def test_stylist_does_not_force_an_outfit_for_a_general_style_question():
    agent = FashionStylistAgent()
    items = [WardrobeItem(name="Black tee", category="Tops", color="Black")]

    response = agent._fallback_response(
        "What colours go with black? Styling brief: occasion=Everyday; aesthetic=Casual. "
        "Owned wardrobe pieces: Black tee.",
        [],
        wardrobe_items=items,
    )

    assert "Black tee" not in response
