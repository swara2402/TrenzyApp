from app.ai.fashion_intelligence.engine import WardrobeItem, rank_outfits


def item(identifier, category, color, styles=(), occasions=()):
    return WardrobeItem(
        id=identifier,
        category=category,
        color=color,
        style_tags=frozenset(styles),
        occasion_tags=frozenset(occasions),
    )


def test_builds_ranked_top_bottom_outfits_with_optional_accessories():
    results = rank_outfits(
        [
            item("top-1", "top", "black", ["minimal"], ["college"]),
            item("bottom-1", "bottom", "beige", ["minimal"], ["college"]),
            item("shoe-1", "footwear", "white", ["minimal"], ["college"]),
            item("earring-1", "accessory", "gold", ["minimal"], ["college"]),
        ],
        occasion="college",
        preferred_styles=["minimal"],
    )

    assert results
    assert results[0].score > 0
    assert any("college" in reason for reason in results[0].reasons)
    assert {x.category for x in results[0].items} >= {"top", "bottom"}


def test_supports_one_piece_outfits_without_top_bottom():
    results = rank_outfits([item("dress-1", "one_piece", "blue")])
    assert len(results) == 1
    assert results[0].items[0].id == "dress-1"


def test_disliked_items_are_excluded_and_liked_items_are_explained():
    results = rank_outfits(
        [
            item("top-1", "top", "black"),
            item("top-2", "top", "white"),
            item("bottom-1", "bottom", "blue"),
        ],
        liked_item_ids=["top-2"],
        disliked_item_ids=["top-1"],
    )

    assert results
    assert all("top-1" not in {x.id for x in candidate.items} for candidate in results)
    liked_candidate = next(x for x in results if "top-2" in {i.id for i in x.items})
    assert any("liked" in reason for reason in liked_candidate.reasons)


def test_rejects_incomplete_or_unknown_categories():
    assert rank_outfits([{"id": "hat", "category": "hat"}]) == []
    assert rank_outfits([{"id": "top", "category": "top"}]) == []


def test_limit_is_respected():
    results = rank_outfits(
        [
            item("t1", "top", "black"),
            item("t2", "top", "white"),
            item("b1", "bottom", "blue"),
            item("b2", "bottom", "beige"),
        ],
        limit=2,
    )
    assert len(results) == 2
