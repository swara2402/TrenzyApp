"""Payment processing with explicit mode configuration and immutable transaction snapshots.

PHASE 5: PAYMENTS - SECURE SIMULATION VS PRODUCTION MODE

Handles order creation, client verification, webhook verification, and payment status tracking.
Supports both simulation mode (development/testing) and Razorpay integration
(production with real payments).

Mode Configuration:
  PAYMENTS_MODE=simulation (default in development):
    - Returns fake successful payments
    - No real payment processing
    - No credentials required
  
  PAYMENTS_MODE=razorpay (required in production):
    - Real Razorpay integration
    - Requires RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET
    - Validates client signatures using RAZORPAY_KEY_SECRET
    - Validates webhook signatures using RAZORPAY_WEBHOOK_SECRET
    - Fails startup if credentials missing

Payment State Machine:
  CREATED -> AUTHORIZED -> CAPTURED -> ORDER_PENDING -> COMPLETED (or FAILED / RECONCILIATION_NEEDED)

Financial Immutability:
  All order item prices, titles, quantities, and totals are snapshotted at payment
  order creation time (snapshot_json) and derive from server-side price records.
  Order finalization derives Order and OrderItem records from the immutable snapshot,
  preventing price manipulation and protecting historical transactions from mutable product price changes.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..auth_deps import require_admin
from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..launch_flags import require_beta_commerce
from ..models import CartItem, Order, OrderItem, Product, Purchase, Purchase, Purchase
from ..models_payments import Payment
from ..config import (
    PAYMENT_CHECKOUT_SECRET,
    PAYMENTS_MODE,
    RAZORPAY_KEY_ID,
    RAZORPAY_KEY_SECRET,
    RAZORPAY_WEBHOOK_SECRET,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/payments", tags=["payments"], dependencies=[Depends(require_beta_commerce)])


def _require_user(request: Request) -> dict[str, Any]:
    """Extract and validate Firebase user from request."""
    decoded = verify_firebase_token(request)
    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")
    return decoded


class CreateOrderRequest(BaseModel):
    """Request to create a payment order."""
    amount_paise: Optional[int] = None


class CreateOrderResponse(BaseModel):
    """Response with payment order details."""
    razorpay_order_id: str
    amount_paise: int
    currency: str = "INR"
    key_id: str
    simulation: bool = False
    checkout_url: Optional[str] = None


class VerifyPaymentRequest(BaseModel):
    """Request to verify payment from client submission."""
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class VerifyPaymentResponse(BaseModel):
    """Response confirming payment verification."""
    status: str
    order_id: str
    message: str


class PaymentStatusResponse(BaseModel):
    """Response with payment/order status for client polling."""
    status: str
    order_id: str = ""
    amount_paise: int
    currency: str = "INR"


def _checkout_secret() -> str:
    """Return the secret used to sign hosted checkout URLs.

    Fail closed: never fall back to a well-known value in production, since
    that would let anyone forge a checkout URL. Production config validation
    (config.py) already enforces that one of the secrets is set.
    """
    from ..config import IS_PRODUCTION

    if PAYMENT_CHECKOUT_SECRET:
        return PAYMENT_CHECKOUT_SECRET
    if RAZORPAY_WEBHOOK_SECRET:
        return RAZORPAY_WEBHOOK_SECRET
    if IS_PRODUCTION:
        raise RuntimeError(
            "PAYMENT_CHECKOUT_SECRET / RAZORPAY_WEBHOOK_SECRET not configured "
            "in production — refusing to sign checkout URLs."
        )
    return "trenzy-dev-checkout-secret"


def _sign_checkout_token(order_id: str) -> str:
    """Sign a checkout URL for an order (stateless; verifiable without a DB row)."""
    return hmac.new(
        _checkout_secret().encode("utf-8"),
        order_id.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _checkout_page(
    order_id: str,
    token: str,
    payment: Payment,
    api_base_url: str,
) -> HTMLResponse:
    """Render the hosted checkout page for an order.

    In simulation mode a lightweight page tells the user the order is complete.
    In Razorpay mode the page embeds Razorpay Checkout (checkout.js) driven by
    the server-issued order id, then posts the result to ``/api/payments/verify``.
    The page never trusts client-supplied amounts — it reads the stored Payment row.
    """
    amount = int(payment.amount_paise or 0)
    currency = payment.currency or "INR"
    rupees = f"{amount / 100:.2f}".rstrip("0").rstrip(".")

    if PAYMENTS_MODE == "simulation":
        return HTMLResponse(_SIM_CHECKOUT_HTML)

    return HTMLResponse(
        _RAZORPAY_CHECKOUT_HTML.format(
            key_id=RAZORPAY_KEY_ID,
            order_id=order_id,
            amount=amount,
            currency=currency,
            rupees=rupees,
            api_base=api_base_url.rstrip("/"),
        )
    )


_SIM_CHECKOUT_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Checkout</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; background:#0d0d14; color:#eee;
           display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
    .card { background:#1a1a26; border:1px solid #2c2c3d; border-radius:16px; padding:32px; max-width:360px; text-align:center; }
    h2 { margin:0 0 8px; } p { color:#9aa; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Order placed (simulation)</h2>
    <p>Payments are running in simulation mode. Your order was recorded and the
       cart cleared. You can return to the Trenzy app.</p>
  </div>
</body>
</html>"""

_RAZORPAY_CHECKOUT_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Trenzy Checkout</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; background:#0d0d14; color:#eee;
           display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
    #rzp-section { padding:24px; text-align:center; }
    #rzp-section a { color:#9db2ff; }
  </style>
</head>
<body>
  <div id="rzp-section">
    <h2>Redirecting to secure payment…</h2>
    <p>Amount: {currency} {rupees}</p>
    <p><small>If nothing happens, <a href="javascript:location.reload()">reload</a>.</small></p>
  </div>
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <script>
    var section = document.getElementById("rzp-section");
    var done = false;

    function showStatus(title, body) {{
      section.innerHTML = "<h2>" + title + "</h2><p>" + body + "</p>";
    }}

    var options = {{
      key: "{key_id}",
      amount: {amount},
      currency: "{currency}",
      name: "Trenzy",
      description: "Trenzy order",
      order_id: "{order_id}",
      notes: {{ purpose: "fashion_order" }},
      modal: {{ backdropclose: false, escape: false }},
      theme: {{ color: "#7C5CFC" }},
      handler: function (response) {{
        if (done) return; done = true;
        showStatus("Confirming payment…", "Please wait.");
        fetch("{api_base}/api/payments/verify", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{
            razorpay_order_id: response.razorpay_order_id,
            razorpay_payment_id: response.razorpay_payment_id,
            razorpay_signature: response.razorpay_signature
          }})
        }}).then(function (r) {{ return r.json(); }})
          .then(function (data) {{
            if (data.order_id) {{
              showStatus("Payment successful",
                "Order " + data.order_id + " confirmed. You can close this page and return to the Trenzy app.");
            }} else {{
              showStatus("Payment received",
                "We are confirming the payment. You can close this page and return to the Trenzy app " +
                "and tap \\'I have completed payment\\'.");
            }}
          }})
          .catch(function () {{
            showStatus("Almost done",
              "Payment was captured. If this page does not update, close it and return to the app " +
              "to confirm your order.");
          }});
      }}
    }};

    var rzp = new Razorpay(options);

    rzp.on("payment.failed", function (response) {{
      showStatus("Payment failed",
        (response.error && response.error.description) || "The payment could not be completed. " +
        "Close this page and try again from the Trenzy app.");
    }});

    options.modal.ondismiss = function () {{
      showStatus("Checkout closed",
        "You can close this page and return to the Trenzy app. " +
        "If you were charged, tap \\'I have completed payment\\' in the app to confirm your order.");
    }};

    rzp.open();
  </script>
</body>
</html>"""


def _cart_total_and_snapshot(
    session: Session, uid: str
) -> tuple[int, list[dict[str, Any]], list[CartItem]]:
    """Compute server-side cart total and generate immutable item snapshot.
    
    Raises HTTPException(400) if cart is empty or total is non-positive.
    Returns (total_paise, snapshot_items, cart_items).
    """
    cart_items = session.query(CartItem).filter(CartItem.user_firebase_uid == uid).all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="Cart is empty")

    product_ids = [ci.product_id for ci in cart_items]
    products_map: dict[str, Product] = {}
    if product_ids:
        products = session.query(Product).filter(Product.id.in_(product_ids)).all()
        products_map = {p.id: p for p in products}

    total_paise = 0
    snapshot: list[dict[str, Any]] = []

    for ci in cart_items:
        product = products_map.get(ci.product_id)
        product_name = product.name if product else ci.product_id
        if product and product.price is not None:
            price_paise = int(float(product.price) * 100)
        else:
            price_paise = 0

        qty = max(ci.quantity, 0)
        subtotal = price_paise * qty
        total_paise += subtotal

        snapshot.append({
            "product_id": ci.product_id,
            "title": product_name,
            "price_cents": price_paise,
            "quantity": qty,
            "subtotal_cents": subtotal,
        })

    if total_paise <= 0:
        raise HTTPException(status_code=400, detail="Cart total must be greater than zero")

    return total_paise, snapshot, cart_items


def _finalize_order_from_snapshot(
    session: Session, uid: str, payment: Payment
) -> str:
    """Create Order + OrderItem rows from immutable payment snapshot and clear cart.
    
    If order already exists for this payment, returns existing order_id.
    Ensures historical order data is completely isolated from mutable product prices.
    """
    if payment.order_id:
        return payment.order_id

    items_data = payment.snapshot_json
    if not items_data:
        # Fallback for legacy payment rows without snapshot_json
        _, items_data, _ = _cart_total_and_snapshot(session, uid)

    order_id = f"ORD_{uuid.uuid4().hex[:12].upper()}"
    payment.order_id = order_id

    order = Order(
        id=order_id,
        user_firebase_uid=uid,
        status="placed",
        items=items_data,
    )
    session.add(order)

    for item in items_data:
        session.add(
            OrderItem(
                order_id=order_id,
                product_id=item["product_id"],
                title=item["title"],
                price_cents=item["price_cents"],
                quantity=item["quantity"],
            )
        )
        # Record purchase history alongside the immutable order snapshot.
        # Without these rows the purchases/orders history surfaces stay empty
        # even though the order was finalized successfully.
        session.add(
            Purchase(
                user_firebase_uid=uid,
                product_id=item["product_id"],
                quantity=item["quantity"],
                price_cents=item["price_cents"],
                currency=item.get("currency", "INR"),
                order_id=order_id,
            )
        )

    # Clear user's active cart
    session.query(CartItem).filter(CartItem.user_firebase_uid == uid).delete(
        synchronize_session=False
    )

    return order_id


@router.post("/order", response_model=CreateOrderResponse)
def create_order(
    request: Request,
    body: CreateOrderRequest,
    session: Session = Depends(get_session),
):
    """Create a payment order for the user's cart.
    
    Always computes cart total server-side and stores an immutable snapshot
    of items and prices to guarantee financial consistency.
    """
    decoded = _require_user(request)
    uid = str(decoded.get("uid"))

    amount_paise, snapshot, _ = _cart_total_and_snapshot(session, uid)
    api_base = str(request.base_url).rstrip("/")

    if PAYMENTS_MODE == "simulation":
        sim_order_id = f"sim_{uuid.uuid4().hex[:16]}"
        logger.info(
            "SIMULATION MODE: Created simulated order %s for user %s (%d paise)",
            sim_order_id, uid, amount_paise
        )

        payment = Payment(
            id=sim_order_id,
            user_firebase_uid=uid,
            amount_paise=amount_paise,
            currency="INR",
            razorpay_order_id=sim_order_id,
            snapshot_json=snapshot,
            status="created",
        )
        session.add(payment)
        session.commit()

        token = _sign_checkout_token(sim_order_id)
        return CreateOrderResponse(
            razorpay_order_id=sim_order_id,
            amount_paise=amount_paise,
            currency="INR",
            key_id="sim_key",
            simulation=True,
            checkout_url=f"{api_base}/api/payments/checkout?order={sim_order_id}&token={token}",
        )

    # Production mode: call Razorpay API
    try:
        with httpx.Client(timeout=10) as client:
            auth = (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET)
            resp = client.post(
                "https://api.razorpay.com/v1/orders",
                json={
                    "amount": amount_paise,
                    "currency": "INR",
                    "receipt": f"txn_{uid[:8]}",
                },
                auth=auth,
            )
            if resp.status_code not in (200, 201):
                logger.error(
                    "Razorpay order creation failed: status=%d, body=%s",
                    resp.status_code, resp.text
                )
                raise HTTPException(status_code=502, detail="Payment gateway error")
            data = resp.json()
    except httpx.RequestError as e:
        logger.error("Razorpay API unreachable: %s", e)
        raise HTTPException(status_code=502, detail="Payment gateway unreachable")

    razorpay_order_id = data["id"]
    payment = Payment(
        id=razorpay_order_id,
        user_firebase_uid=uid,
        amount_paise=amount_paise,
        currency="INR",
        razorpay_order_id=razorpay_order_id,
        snapshot_json=snapshot,
        status="created",
    )
    session.add(payment)
    session.commit()

    token = _sign_checkout_token(razorpay_order_id)
    return CreateOrderResponse(
        razorpay_order_id=razorpay_order_id,
        amount_paise=amount_paise,
        currency="INR",
        key_id=RAZORPAY_KEY_ID,
        simulation=False,
        checkout_url=f"{api_base}/api/payments/checkout?order={razorpay_order_id}&token={token}",
    )


def _verify_razorpay_client_signature(
    razorpay_order_id: str,
    razorpay_payment_id: str,
    razorpay_signature: str,
) -> bool:
    """Verify client Razorpay payment signature using HMAC-SHA256 with key_secret.
    
    Razorpay integration contract:
      HMAC-SHA256("{order_id}|{payment_id}", RAZORPAY_KEY_SECRET)
    """
    if PAYMENTS_MODE == "simulation":
        return True

    if not RAZORPAY_KEY_SECRET:
        logger.error("RAZORPAY_KEY_SECRET is missing — failing closed on payment verification")
        return False

    message = f"{razorpay_order_id}|{razorpay_payment_id}"
    expected_signature = hmac.new(
        RAZORPAY_KEY_SECRET.encode("utf-8"),
        message.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected_signature, razorpay_signature)


@router.post("/verify", response_model=VerifyPaymentResponse)
def verify_payment(
    request: Request,
    body: VerifyPaymentRequest,
    session: Session = Depends(get_session),
):
    """Verify payment from client and finalize order.
    
    Uses row-level locking and explicit state transitions:
    CREATED -> CAPTURED -> COMPLETED (or ORDER_PENDING if order creation needs reconciliation).
    """
    decoded = _require_user(request)
    uid = str(decoded.get("uid"))

    if not _verify_razorpay_client_signature(
        body.razorpay_order_id,
        body.razorpay_payment_id,
        body.razorpay_signature,
    ):
        logger.warning(
            "Client signature verification failed for user %s order %s",
            uid, body.razorpay_order_id
        )
        raise HTTPException(status_code=400, detail="Signature verification failed")

    # Find payment record with row lock
    payment = (
        session.query(Payment)
        .filter(
            Payment.razorpay_order_id == body.razorpay_order_id,
            Payment.user_firebase_uid == uid,
        )
        .with_for_update()
        .first()
    )

    if not payment:
        logger.warning("Payment record not found for user %s order %s", uid, body.razorpay_order_id)
        raise HTTPException(status_code=404, detail="Order not found")

    # Idempotency check: already finalized
    if payment.status == "completed" and payment.order_id:
        logger.info("Idempotent verify request for completed payment %s", body.razorpay_order_id)
        return VerifyPaymentResponse(
            status="completed",
            order_id=payment.order_id,
            message="Payment already completed",
        )

    # Transition to captured
    payment.status = "captured"
    payment.razorpay_payment_id = body.razorpay_payment_id
    payment.razorpay_signature = body.razorpay_signature
    payment.verified_at = datetime.now(timezone.utc)

    try:
        order_id = _finalize_order_from_snapshot(session, uid, payment)
        payment.status = "completed"
        payment.error_message = None
        session.commit()

        logger.info("Payment verified and order finalized: order_id=%s, user=%s", order_id, uid)
        return VerifyPaymentResponse(
            status="completed",
            order_id=order_id,
            message="Payment verified and order created",
        )
    except Exception as e:
        session.rollback()
        # Preserve captured payment state with order_pending for safe reconciliation
        try:
            payment_reconcile = (
                session.query(Payment)
                .filter(Payment.id == payment.id)
                .first()
            )
            if payment_reconcile:
                payment_reconcile.status = "order_pending"
                payment_reconcile.razorpay_payment_id = body.razorpay_payment_id
                payment_reconcile.verified_at = datetime.now(timezone.utc)
                payment_reconcile.error_message = str(e)
                session.commit()
        except Exception as inner_e:
            logger.error("Failed to record order_pending status: %s", inner_e)

        logger.error("Failed to finalize order for payment %s: %s", body.razorpay_order_id, e)
        raise HTTPException(
            status_code=500,
            detail="Payment captured but order creation is pending reconciliation. Please retry verification.",
        )


@router.get("/order/{razorpay_order_id}", response_model=PaymentStatusResponse)
def payment_status(
    request: Request,
    razorpay_order_id: str,
    session: Session = Depends(get_session),
):
    """Return the current state of a payment order for client-side polling.

    The client opens the hosted checkout page in a browser/WebView, then after
    the user returns it polls this endpoint until the webhook or verify call
    moves the payment to ``completed`` (in which case ``order_id`` is set).
    """
    caller = _require_user(request)
    caller_uid = str(caller.get("uid") or caller.get("firebase_uid") or "")
    payment = (
        session.query(Payment)
        .filter(
            Payment.razorpay_order_id == razorpay_order_id,
            Payment.user_firebase_uid == caller_uid,
        )
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Order not found")
    # Users may only poll the status of their own orders.
    if str(payment.user_firebase_uid) != caller_uid:
        raise HTTPException(status_code=403, detail="Cannot view another user's order")

    return PaymentStatusResponse(
        status=payment.status,
        order_id=payment.order_id or "",
        amount_paise=payment.amount_paise,
        currency=payment.currency or "INR",
    )


@router.get("/checkout", response_class=HTMLResponse)
def checkout_page(
    request: Request,
    order: str = Query(...),
    token: str = Query(...),
    session: Session = Depends(get_session),
):
    """Serve the hosted checkout page for an order.

    The URL is signed at order creation and returned as ``checkout_url``, so a
    user can complete payment without an authenticated app session.
    """
    if not hmac.compare_digest(token, _sign_checkout_token(order)):
        raise HTTPException(status_code=401, detail="Invalid checkout token")

    payment = (
        session.query(Payment)
        .filter(Payment.razorpay_order_id == order)
        .first()
    )
    if not payment:
        raise HTTPException(status_code=404, detail="Order not found")

    return _checkout_page(order, token, payment, str(request.base_url))


# In-memory webhook metrics tracking (for operational monitoring & alerting)
_webhook_metrics = {
    "received": 0,
    "verified": 0,
    "failed_signature": 0,
    "failed_amount": 0,
    "order_pending": 0,
    "completed": 0,
}


@router.get("/webhook-status")
def get_webhook_status(
    session: Session = Depends(get_session),
    _admin: dict = Depends(require_admin),
):
    """Operational monitoring endpoint: webhook metrics and pending reconciliation status.

    Requires admin authentication. Exposes internal payment mode and reconciliation
    metrics — do not make this publicly accessible.
    """
    pending_reconciliation_count = (
        session.query(Payment)
        .filter(Payment.status == "order_pending")
        .count()
    )
    return {
        "status": "ok",
        "mode": PAYMENTS_MODE,
        "metrics": _webhook_metrics,
        "pending_reconciliations": pending_reconciliation_count,
    }


@router.post("/webhook")
async def payment_webhook(request: Request, session: Session = Depends(get_session)):
    """Razorpay webhook handler for server-to-server payment notifications.
    
    Security:
    - HMAC-SHA256 verification using RAZORPAY_WEBHOOK_SECRET
    - Row-level locking prevents race conditions and ensures idempotency
    - Never marks order completed if order finalization fails
    """
    _webhook_metrics["received"] += 1

    if PAYMENTS_MODE == "simulation":
        logger.debug("Webhook received in simulation mode - ignoring")
        return {"status": "ok"}

    if not RAZORPAY_WEBHOOK_SECRET:
        logger.warning("Webhook called but RAZORPAY_WEBHOOK_SECRET is not configured")
        raise HTTPException(status_code=501, detail="Webhooks not configured")

    raw_body = await request.body()
    received_sig = request.headers.get("x-razorpay-signature", "")

    expected_sig = hmac.new(
        RAZORPAY_WEBHOOK_SECRET.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(received_sig, expected_sig):
        _webhook_metrics["failed_signature"] += 1
        logger.warning("Webhook signature verification failed (received length=%d)", len(received_sig))
        raise HTTPException(status_code=400, detail="Invalid webhook signature")

    _webhook_metrics["verified"] += 1

    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as e:
        logger.error("Webhook payload is not valid JSON: %s", e)
        raise HTTPException(status_code=400, detail="Invalid JSON payload")

    event = payload.get("event", "")
    event_data = payload.get("payload", {}).get("payment", {}).get("entity", {})

    logger.info(
        "Webhook event: %s (razorpay_order_id=%s)",
        event, event_data.get("order_id", "unknown")
    )

    if event == "payment.captured":
        payment_id = event_data.get("id", "")
        order_id = event_data.get("order_id", "")

        if not payment_id or not order_id:
            logger.error("Webhook: Missing payment_id or order_id in event_data")
            raise HTTPException(status_code=400, detail="Missing payment or order ID")

        payment = (
            session.query(Payment)
            .filter(Payment.razorpay_order_id == order_id)
            .with_for_update()
            .first()
        )

        if not payment:
            logger.warning("Webhook: Payment not found for order %s", order_id)
            raise HTTPException(status_code=404, detail="Payment order not found")

        # Idempotency check
        if payment.status == "completed" and payment.order_id:
            logger.info("Webhook: Duplicate payment.captured for completed order %s", order_id)
            return {"status": "ok", "idempotent": True}

        # Verify the captured amount matches the immutable order snapshot.
        # Reject any mismatch instead of finalizing the order — this prevents
        # completing orders that were captured for the wrong amount.
        captured_amount = event_data.get("amount")
        if captured_amount is not None and int(captured_amount) != int(payment.amount_paise):
            log_msg = (
                "Webhook: AMOUNT MISMATCH for order %s — expected %s paise, "
                "captured %s paise. Refusing to finalize.",
                order_id, payment.amount_paise, captured_amount,
            )
            logger.error(*log_msg)
            _webhook_metrics["failed_amount"] += 1
            payment.status = "amount_mismatch"
            payment.error_message = (
                f"Captured amount {captured_amount} != expected {payment.amount_paise}"
            )
            session.commit()
            raise HTTPException(
                status_code=400,
                detail="Captured amount does not match order amount",
            )

        payment.status = "captured"
        payment.razorpay_payment_id = payment_id
        payment.verified_at = datetime.now(timezone.utc)

        try:
            _finalize_order_from_snapshot(session, payment.user_firebase_uid, payment)
            payment.status = "completed"
            payment.error_message = None
            _webhook_metrics["completed"] += 1
        except Exception as e:
            logger.warning("Webhook: Order finalization deferred for %s: %s", order_id, e)
            payment.status = "order_pending"
            payment.error_message = str(e)
            _webhook_metrics["order_pending"] += 1

        session.commit()
        logger.info("Webhook: Processed payment %s for order %s (status=%s)", payment_id, order_id, payment.status)
        return {"status": "ok"}

    return {"status": "ok", "ignored": True}