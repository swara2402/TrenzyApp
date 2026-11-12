"""Regression coverage for the shared, behavior-aware Home For You ranking."""

from app.models import DiscoverySwipe, Product


def test_home_for_you_uses_positive_and_negative_discovery_feedback(
    client, auth_headers, db_session
):
    liked = Product(
        id="feed-liked-1",
        name="Liked casual top",
        brand="TestBrand",
        category="tops",
        style="casual",
        color="black",
        rating=4.0,
        is_archived=False,
    )
    disliked = Product(
        id="feed-disliked-1",
        name="Disliked casual top",
        brand="OtherBrand",
        category="tops",
        style="casual",
        color="black",
        rating=5.0,
        is_archived=False,
    )
    db_session.add_all([liked, disliked])
    db_session.flush()
    db_session.add_all([
        DiscoverySwipe(
            user_firebase_uid="test-user-1",
            product_id=liked.id,
            score=1,
        ),
        DiscoverySwipe(
            user_firebase_uid="test-user-1",
            product_id=disliked.id,
            score=-1,
        ),
    ])
    db_session.commit()

    response = client.get("/api/feed", headers=auth_headers)

    assert response.status_code == 200
    sections = {section["id"]: section for section in response.json()["sections"]}
    for_you = sections["for_you"]
    product_ids = {item["id"] for item in for_you["products"]}

    assert liked.id in product_ids
    assert disliked.id not in product_ids
    assert for_you["reasons"][liked.id]
