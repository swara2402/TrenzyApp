"""Tests for user profiles, cascade deletion, and financial audit record retention."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import User, Cart, CartItem, WardrobeItem, Order, Product
from app.models_payments import Payment


def test_user_profile_update(client: TestClient, db_session: Session, auth_headers):
    """User can update their display name and bio."""
    uid = "test-user-1"
    headers = auth_headers

    user = User(firebase_uid=uid, email="prof1@example.com", name="Old Name")
    db_session.add(user)
    db_session.commit()

    res = client.patch(
        "/api/users/me",
        json={"name": "New Name", "bio": "Fashion lover"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["user"]["name"] == "New Name"
    assert data["user"]["bio"] == "Fashion lover"


def test_user_account_deletion_with_financial_preservation(
    client: TestClient, db_session: Session, auth_headers
):
    """Account deletion removes personal data but anonymizes financial records."""
    uid = "test-user-1"
    headers = auth_headers

    user = User(firebase_uid=uid, email="del1@example.com", name="Delete Me")
    db_session.add(user)

    # Seed product first so FK is satisfied
    p = Product(id="prod_del_1", name="Delete Product", price=100.0)
    db_session.add(p)
    db_session.commit()

    # Add personal items (should be cascade deleted)
    cart = Cart(user_firebase_uid=uid)
    db_session.add(cart)
    db_session.commit()

    cart_item = CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_del_1", quantity=1)
    wardrobe_item = WardrobeItem(user_firebase_uid=uid, name="Blue Jeans")
    db_session.add_all([cart_item, wardrobe_item])

    # Add financial audit records (should be anonymized, not deleted)
    order = Order(id="ORD_DEL_TEST_1", user_firebase_uid=uid, status="placed", items=[])
    payment = Payment(
        id="pay_del_test_1",
        razorpay_order_id="pay_del_test_1",
        user_firebase_uid=uid,
        amount_paise=10000,
        currency="INR",
        status="completed",
    )
    db_session.add_all([order, payment])
    db_session.commit()

    # Call DELETE /api/users/me
    res = client.delete("/api/users/me", headers=headers)
    assert res.status_code == 200
    assert res.json() == {"ok": True}

    # Verify user record is deleted
    assert db_session.query(User).filter(User.firebase_uid == uid).first() is None

    # Verify cart and wardrobe are deleted
    assert (
        db_session.query(CartItem).filter(CartItem.user_firebase_uid == uid).first()
        is None
    )
    assert (
        db_session.query(WardrobeItem)
        .filter(WardrobeItem.user_firebase_uid == uid)
        .first()
        is None
    )

    # Verify financial records still exist with anonymized ID
    anonymized_id = f"anonymized_{uid[:8]}"
    db_order = db_session.query(Order).filter(Order.id == "ORD_DEL_TEST_1").first()
    assert db_order is not None
    assert db_order.user_firebase_uid == anonymized_id

    db_payment = db_session.query(Payment).filter(Payment.id == "pay_del_test_1").first()
    assert db_payment is not None
    assert db_payment.user_firebase_uid == anonymized_id
