from types import SimpleNamespace

from app.models import Product
from app.routes.products import _canonical_category, _product_tags
from app.scripts.seed_from_manifest import build_product_record, infer_category
from app.scripts.quarantine_unclassified_products import grounded_tags, is_unclassified


def test_legacy_style_groups_normalize_to_garment_categories():
    assert _canonical_category("baggy washed denim jeans") == "Bottoms"
    assert _canonical_category("retro basketball sneakers") == "Footwear"
    assert _canonical_category("technical windbreaker") == "Outerwear"
    assert _canonical_category("football jersey") == "Tops"
    assert _canonical_category("layered streetwear outfit") == ""


def test_unclassified_catalog_records_are_quarantined_not_guessed():
    assert is_unclassified({"category": "unknown", "subcategory": "unknown", "gender": "unknown"})
    assert is_unclassified({"category": "footwear", "subcategory": "unknown", "gender": "men"})
    assert is_unclassified({"category": "streetwear", "subcategory": "layered streetwear outfit", "gender": "men"})
    assert not is_unclassified({"category": "footwear", "subcategory": "retro trainers", "gender": "men"})


def test_grounded_tags_use_only_existing_metadata_and_dedupe_case_insensitively():
    product = {
        "category": "footwear",
        "subcategory": "Retro Trainers",
        "style": "Streetwear",
        "color": "Black",
        "gender": "men",
    }
    assert grounded_tags(product) == ["Retro Trainers", "Footwear", "Streetwear", "Black", "men"]


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
    assert tags == ["Streetwear", "Black", "retro trainers", "Footwear", "men"]
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


def test_products_endpoint_hides_unclassified_rows(client, db_session):
    unclassified = Product(
        id="test_unclassified_catalog_row",
        name="Museum Archive Image",
        category="unknown",
        subcategory="unknown",
        gender="unknown",
        image_url="https://example.test/archive.jpg",
        is_archived=False,
    )
    classified = Product(
        id="test_classified_catalog_row",
        name="Retro Trainers",
        category="streetwear",
        subcategory="retro trainers",
        gender="men",
        image_url="https://example.test/trainers.jpg",
        tags=["retro trainers", "footwear", "men"],
        is_archived=False,
    )
    db_session.add_all([unclassified, classified])
    db_session.commit()

    response = client.get("/api/products?limit=100")
    assert response.status_code == 200
    ids = {item["id"] for item in response.json()["products"]}
    assert "test_classified_catalog_row" in ids
    assert "test_unclassified_catalog_row" not in ids
    classified_item = next(item for item in response.json()["products"] if item["id"] == "test_classified_catalog_row")
    assert classified_item["category"] == "Footwear"

    categories_response = client.get("/api/categories")
    assert categories_response.status_code == 200
    categories = categories_response.json()
    assert "Footwear" in categories
    assert "streetwear" not in categories
    assert "unknown" not in categories



def test_manifest_seed_never_guesses_category_or_invents_price():
    assert infer_category("Beskid Museum exhibits", "") is None
    assert build_product_record({
        "title": "Beskid Museum exhibits",
        "image_url": "https://example.test/archive.jpg",
        "sha256": "abc123",
    }, 1) is None
    assert build_product_record({
        "title": "Black Retro Sneakers",
        "image_url": "https://example.test/sneakers.jpg",
        "sha256": "def456",
    }, 2) is None


def test_manifest_seed_accepts_explicit_price_and_recognized_item_type():
    product = build_product_record({
        "title": "Black Retro Sneakers",
        "image_url": "https://example.test/sneakers.jpg",
        "sha256": "def456",
        "price": 1299,
        "source": "verified supplier feed",
        "license": "owner-provided",
    }, 3)
    assert product is not None
    assert product["category"] == "footwear"
    assert product["price"] == 1299.0
    assert product["brand"] is None
    assert product["style"] is None



def test_product_search_can_sort_catalog_without_search_text(client, db_session):
    lower_rated = Product(
        id="sort_only_lower_rated",
        name="Canvas Trainers",
        category="footwear",
        subcategory="retro trainers",
        gender="men",
        rating=3.2,
        price=1299,
        is_archived=False,
    )
    higher_rated = Product(
        id="sort_only_higher_rated",
        name="Classic Sneakers",
        category="footwear",
        subcategory="retro trainers",
        gender="men",
        rating=4.9,
        price=2199,
        is_archived=False,
    )
    db_session.add_all([lower_rated, higher_rated])
    db_session.commit()

    response = client.get("/api/products/search?sort=rating_desc")
    assert response.status_code == 200
    ids = [item["id"] for item in response.json()["products"]]
    assert ids.index("sort_only_higher_rated") < ids.index("sort_only_lower_rated")
