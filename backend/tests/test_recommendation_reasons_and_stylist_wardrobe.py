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



def test_stylist_selects_one_saree_then_coordinates_jewellery():
    agent = FashionStylistAgent()
    items = [
        WardrobeItem(id=1, name="Blue silk saree", category="Saree", color="Royal blue", is_favorite=False, image_url="blue.jpg"),
        WardrobeItem(id=2, name="Wine silk saree", category="Sarees", color="Wine", is_favorite=True, image_url="wine.jpg"),
        WardrobeItem(id=3, name="Gold jhumkas", category="Jewellery", color="Gold", is_favorite=True),
        WardrobeItem(id=4, name="Silver hoops", category="Earrings", color="Silver"),
        WardrobeItem(id=5, name="Gold necklace", category="Necklace", color="Gold"),
        WardrobeItem(id=6, name="Pearl choker", category="Necklace", color="Pearl"),
        WardrobeItem(id=7, name="Gold bangles", category="Bangles", color="Gold"),
        WardrobeItem(id=8, name="Nude heels", category="Footwear", color="Nude"),
    ]

    response = agent._fallback_response(
        "Choose the best saree from these and style the full look. "
        "Styling brief: occasion=Party; aesthetic=Classic. "
        "Owned wardrobe pieces: selected items.",
        [],
        wardrobe_items=items,
    )

    assert "My pick: **Wine silk saree**" in response
    assert "Blue silk saree" not in response
    assert "Gold jhumkas" in response
    assert "Gold necklace" in response
    assert "Gold bangles" in response
    assert "Nude heels" in response
    assert response.count("saree**") == 1



def test_stylist_compares_dresses_and_coordinates_accessories_for_any_occasion():
    agent = FashionStylistAgent()
    items = [
        WardrobeItem(id=11, name="Pink party dress", category="Dresses", color="Pink"),
        WardrobeItem(id=12, name="Black evening dress", category="Dress", color="Black", is_favorite=True),
        WardrobeItem(id=13, name="Silver hoops", category="Jewellery", color="Silver"),
        WardrobeItem(id=14, name="Pearl necklace", category="Necklace", color="Pearl"),
        WardrobeItem(id=15, name="Black heels", category="Footwear", color="Black"),
        WardrobeItem(id=16, name="Black clutch", category="Bags", color="Black"),
    ]

    response = agent._fallback_response(
        "Help me decide which dress to wear and complete the look. "
        "Styling brief: occasion=Party; aesthetic=Classic. "
        "Owned wardrobe pieces: selected items.",
        [],
        wardrobe_items=items,
    )

    assert "My pick: **Black evening dress**" in response
    assert "Pink party dress" not in response
    assert "Silver hoops" in response
    assert "Pearl necklace" in response
    assert "Black heels" in response
    assert "Black clutch" in response
    assert "\n" in response



def test_stylist_compares_two_piece_looks_as_a_complete_candidate():
    agent = FashionStylistAgent()
    items = [
        WardrobeItem(id=21, name="Pink dress", category="Dress", color="Pink"),
        WardrobeItem(id=22, name="Black tailored top", category="Tops", color="Black", is_favorite=True),
        WardrobeItem(id=23, name="Beige trousers", category="Bottoms", color="Beige", is_favorite=True),
        WardrobeItem(id=24, name="White sneakers", category="Footwear", color="White"),
    ]

    response = agent._fallback_response(
        "Choose my best outfit and complete the look. "
        "Styling brief: occasion=College; aesthetic=Minimal. "
        "Owned wardrobe pieces: selected items.",
        [],
        wardrobe_items=items,
    )

    assert "Black tailored top" in response
    assert "Beige trousers" in response
    assert "White sneakers" in response
