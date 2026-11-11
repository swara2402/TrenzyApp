"""Focused tests for explainable product recommendations and owned-closet styling."""

from types import SimpleNamespace

from app.ai.stylist.fashion_stylist import FashionStylistAgent
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
    assert "a category you have liked" in reason


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
