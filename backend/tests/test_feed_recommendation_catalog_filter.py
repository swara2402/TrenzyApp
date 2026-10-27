"""Regression tests for catalog quarantine in feed and recommendations."""
from app.models import Product


def _insert_catalog_pair(db_session):
    classified_id = "test_feed_classified_catalog_item"
    unclassified_id = "test_feed_unclassified_catalog_item"
    db_session.query(Product).filter(
        Product.id.in_([classified_id, unclassified_id])
    ).delete(synchronize_session=False)
    db_session.add_all([
        Product(
            id=classified_id,
            name="Retro Trainers",
            category="footwear",
            subcategory="retro trainers",
            gender="men",
            image_url="https://example.test/trainers.jpg",
            tags=["retro trainers", "footwear", "men"],
            price=1299,
            rating=4.8,
            is_archived=False,
        ),
        Product(
            id=unclassified_id,
            name="Unclassified Archive Image",
            category="unknown",
            subcategory="unknown",
            gender="unknown",
            image_url="https://example.test/archive.jpg",
            price=1299,
            rating=5.0,
            is_archived=False,
        ),
    ])
    db_session.commit()
    return classified_id, unclassified_id


def test_feed_product_sections_exclude_unclassified_catalog_rows(client, db_session):
    classified_id, unclassified_id = _insert_catalog_pair(db_session)

    response = client.get("/api/feed?limit=50")
    assert response.status_code == 200, response.text

    sections = response.json()["sections"]
    product_sections = [
        section for section in sections
        if section.get("id") in {"trending", "just_dropped", "for_you"}
    ]
    assert {section["id"] for section in product_sections} == {
        "trending", "just_dropped", "for_you"
    }
    for section in product_sections:
        ids = {item["id"] for item in section.get("products", [])}
        assert classified_id in ids
        assert unclassified_id not in ids


def test_recommend_products_excludes_unclassified_catalog_rows(client, db_session):
    classified_id, unclassified_id = _insert_catalog_pair(db_session)

    response = client.get("/api/recommend/products?limit=50")
    assert response.status_code == 200, response.text

    ids = {item["id"] for item in response.json()["products"]}
    assert classified_id in ids
    assert unclassified_id not in ids
