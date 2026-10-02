"""Tests for payment order creation, snapshots, client verification, and webhooks."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import Cart, CartItem, Product, Order, OrderItem
from app.models_payments import Payment
from app.routes.payments import _verify_razorpay_client_signature


def test_payment_order_creation_with_immutable_snapshot(
    client: TestClient, db_session: Session, auth_headers
):
    """Verify order creation computes cart total and creates an immutable snapshot."""
    uid = "test-user-1"
    headers = auth_headers

    # Seed products
    p1 = Product(id="prod_pay_1", name="Silk Shirt", price=2500.0, category="Clothing")
    p2 = Product(id="prod_pay_2", name="Leather Belt", price=800.0, category="Accessories")
    db_session.add_all([p1, p2])
    db_session.commit()

    # Seed cart
    cart = Cart(user_firebase_uid=uid)
    db_session.add(cart)
    db_session.commit()

    c1 = CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_pay_1", quantity=2)
    c2 = CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_pay_2", quantity=1)
    db_session.add_all([c1, c2])
    db_session.commit()

    # Call /api/payments/order
    res = client.post("/api/payments/order", json={}, headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert "razorpay_order_id" in data
    # (2500 * 2 + 800 * 1) * 100 paise = 580000 paise
    assert data["amount_paise"] == 580000

    # Verify payment record has snapshot_json
    payment = (
        db_session.query(Payment)
        .filter(Payment.razorpay_order_id == data["razorpay_order_id"])
        .first()
    )
    assert payment is not None
    assert payment.status == "created"
    assert payment.snapshot_json is not None
    assert len(payment.snapshot_json) == 2
    assert payment.snapshot_json[0]["product_id"] == "prod_pay_1"
    assert payment.snapshot_json[0]["price_cents"] == 250000
    assert payment.snapshot_json[0]["quantity"] == 2


def test_payment_verification_and_order_finalization(
    client: TestClient, db_session: Session, auth_headers
):
    """Verify payment transitions status, creates Order and OrderItems from snapshot, and clears cart."""
    uid = "test-user-1"
    headers = auth_headers

    p = Product(id="prod_verify_1", name="Sneakers", price=4500.0, category="Footwear")
    db_session.add(p)
    db_session.commit()

    cart = Cart(user_firebase_uid=uid)
    db_session.add(cart)
    db_session.commit()

    c = CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_verify_1", quantity=1)
    db_session.add(c)
    db_session.commit()

    # 1. Create order
    order_res = client.post("/api/payments/order", json={}, headers=headers)
    assert order_res.status_code == 200, order_res.text
    order_id = order_res.json()["razorpay_order_id"]

    # 2. Verify payment
    verify_res = client.post(
        "/api/payments/verify",
        json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": "pay_mock_12345",
            "razorpay_signature": "sig_mock_simulation",
        },
        headers=headers,
    )
    assert verify_res.status_code == 200, verify_res.text
    vdata = verify_res.json()
    assert vdata["status"] == "completed"
    final_order_id = vdata["order_id"]
    assert final_order_id.startswith("ORD_")

    # Check Order and OrderItems in DB
    order = db_session.query(Order).filter(Order.id == final_order_id).first()
    assert order is not None
    assert order.user_firebase_uid == uid
    assert order.status == "placed"

    order_items = (
        db_session.query(OrderItem)
        .filter(OrderItem.order_id == final_order_id)
        .all()
    )
    assert len(order_items) == 1
    assert order_items[0].product_id == "prod_verify_1"
    assert order_items[0].price_cents == 450000

    # Cart should now be empty
    remaining_cart = (
        db_session.query(CartItem)
        .filter(CartItem.user_firebase_uid == uid)
        .all()
    )
    assert len(remaining_cart) == 0

    # 3. Idempotent re-verification
    repeat_res = client.post(
        "/api/payments/verify",
        json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": "pay_mock_12345",
            "razorpay_signature": "sig_mock_simulation",
        },
        headers=headers,
    )
    assert repeat_res.status_code == 200
    assert repeat_res.json()["order_id"] == final_order_id


def test_payment_client_signature_verification_logic():
    """Test Razorpay client HMAC verification directly."""
    # Simulation mode returns True
    assert _verify_razorpay_client_signature("ord_1", "pay_1", "sig_1") is True


def test_checkout_url_and_hosted_page(
    client: TestClient, db_session: Session, auth_headers
):
    """Order creation returns a signed checkout URL that serves a hosted page."""
    uid = "test-user-1"

    p = Product(id="prod_checkout_1", name="Denim Jacket", price=1999.0, category="Outerwear")
    db_session.add(p)
    db_session.commit()

    cart = Cart(user_firebase_uid=uid)
    db_session.add(cart)
    db_session.commit()
    db_session.add(
        CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_checkout_1", quantity=1)
    )
    db_session.commit()

    res = client.post("/api/payments/order", json={}, headers=auth_headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["simulation"] is True
    assert data["checkout_url"], "checkout_url must be present"
    assert data["checkout_url"].startswith("http")

    # Valid token serves the checkout page
    page = client.get(data["checkout_url"])
    assert page.status_code == 200
    assert "text/html" in page.headers["content-type"]

    # Tampered token is rejected
    bad = client.get(data["checkout_url"].replace("token=", "token=deadbeef"))
    assert bad.status_code == 401

    # Unknown order is rejected
    from app.routes.payments import _sign_checkout_token
    unknown = client.get(f"/api/payments/checkout?order=sim_missing&token={_sign_checkout_token('sim_missing')}")
    assert unknown.status_code == 404


def test_payment_status_polling(
    client: TestClient, db_session: Session, auth_headers
):
    """Client can poll payment status, then sees completed once finalized."""
    uid = "test-user-1"

    p = Product(id="prod_status_1", name="Tote Bag", price=1200.0, category="Accessories")
    db_session.add(p)
    db_session.commit()

    cart = Cart(user_firebase_uid=uid)
    db_session.add(cart)
    db_session.commit()
    db_session.add(
        CartItem(cart_id=cart.id, user_firebase_uid=uid, product_id="prod_status_1", quantity=1)
    )
    db_session.commit()

    order_res = client.post("/api/payments/order", json={}, headers=auth_headers)
    order_id = order_res.json()["razorpay_order_id"]

    # Before payment: status is created
    status_res = client.get(f"/api/payments/order/{order_id}", headers=auth_headers)
    assert status_res.status_code == 200
    assert status_res.json()["status"] == "created"
    assert status_res.json()["order_id"] == ""

    # Status requires auth
    anon = client.get(f"/api/payments/order/{order_id}")
    assert anon.status_code in (401, 403)

    # After verify: status is completed with an order id
    verify = client.post(
        "/api/payments/verify",
        json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": "pay_status_1",
            "razorpay_signature": "sig_status_1",
        },
        headers=auth_headers,
    )
    assert verify.status_code == 200

    status_res2 = client.get(f"/api/payments/order/{order_id}", headers=auth_headers)
    assert status_res2.json()["status"] == "completed"
    assert status_res2.json()["order_id"].startswith("ORD_")

    # Unknown order -> 404
    missing = client.get("/api/payments/order/sim_nope", headers=auth_headers)
    assert missing.status_code == 404


def test_webhook_status_requires_admin(client: TestClient, db_session: Session, auth_headers):
    """Ensure /api/payments/webhook-status requires admin authentication."""
    from app.models import User

    # 1. Anonymous request -> 401
    res_anon = client.get("/api/payments/webhook-status")
    assert res_anon.status_code == 401

    # 2. Non-admin authenticated user -> 403
    uid = "test-user-1"
    user = db_session.query(User).filter(User.firebase_uid == uid).first()
    if not user:
        user = User(firebase_uid=uid, name="testuser", is_admin=False)
        db_session.add(user)
    else:
        user.is_admin = False
    db_session.commit()

    res_user = client.get("/api/payments/webhook-status", headers=auth_headers)
    assert res_user.status_code == 403

    # 3. Admin user -> 200
    user.is_admin = True
    db_session.commit()

    res_admin = client.get("/api/payments/webhook-status", headers=auth_headers)
    assert res_admin.status_code == 200
    data = res_admin.json()
    assert data["status"] == "ok"
    assert "metrics" in data
    assert "mode" in data

