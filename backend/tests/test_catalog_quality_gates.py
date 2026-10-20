from types import SimpleNamespace

from app.routes.products import _product_tags
from app.scripts.quarantine_unclassified_products import grounded_tags, is_unclassified


def test_unclassified_catalog_records_are_quarantined_not_guessed():
    assert is_unclassified({"category": "unknown", "subcategory": "unknown", "gender": "unknown"})
    assert is_unclassified({"category": "footwear", "subcategory": "unknown", "gender": "men"})
    assert not is_unclassified({"category": "footwear", "subcategory": "retro trainers", "gender": "men"})


def test_grounded_tags_use_only_existing_metadata_and_dedupe_case_insensitively():
    product = {
        "category": "footwear",
        "subcategory": "Retro Trainers",
        "style": "Streetwear",
        "color": "Black",
        "gender": "men",
    }
    assert grounded_tags(product) == ["Retro Trainers", "footwear", "Streetwear", "Black", "men"]


def test_api_tag_normalizer_accepts_legacy_json_objects_and_returns_string_list():
    product = SimpleNamespace(
        tags={"style": "Streetwear", "color": "Black"},
        subcategory="retro trainers",
        category="footwear",
        style="Streetwear",
        color="Black",
        occasion=None,
        gender="men",
    )
    tags = _product_tags(product)
    assert tags == ["Streetwear", "Black", "retro trainers", "footwear", "men"]
    assert all(isinstance(tag, str) for tag in tags)


def test_api_tag_normalizer_drops_unknown_values():
    product = SimpleNamespace(
        tags=None,
        subcategory="unknown",
        category="unknown",
        style=None,
        color="Navy",
        occasion=None,
        gender="men",
    )
    assert _product_tags(product) == ["Navy", "men"]
