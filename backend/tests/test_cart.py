import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models import Product, Cart, CartItem
from app.main import api as app # Import the FastAPI app instance

# Assuming these fixtures are defined in conftest.py and available
# client: TestClient
# auth_headers: dict
# db_session: Session

# Helper function to create a product for testing
def create_product(session: Session, price: float = 10.0, name: str = "Test Product") -> Product:
    product_id = str(uuid.uuid4()) # Generate a unique product ID
    product = Product(id=product_id, name=name, description="A test product", price=price, image_url="http://example.com/image.jpg")
    session.add(product)
    session.commit()
    session.refresh(product)
    return product

@pytest.fixture
def test_products(db_session: Session):
    product1 = create_product(db_session, 10.0, "Product One")
    product2 = create_product(db_session, 20.0, "Product Two")
    return {"prod1": product1, "prod2": product2}

def test_unauthenticated_cart_access(client: TestClient):
    """
    Test that unauthenticated requests to cart endpoints return 401.
    """
    response = client.get("/api/cart")
    assert response.status_code == 401

    response = client.post("/api/cart/items", json={"product_id": "any", "quantity": 1})
    assert response.status_code == 401

    response = client.put("/api/cart/items/any", json={"quantity": 1})
    assert response.status_code == 401

    response = client.delete("/api/cart/items/any")
    assert response.status_code == 401

    response = client.delete("/api/cart")
    assert response.status_code == 401

def test_add_new_item_to_cart(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test adding a new product to an empty cart.
    """
    product_id = test_products["prod1"].id
    response = client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 1})
    assert response.status_code == 200
    data = response.json()
    assert data["product_id"] == product_id
    assert data["quantity"] == 1

    # Verify in DB
    cart_item = db_session.query(CartItem).filter_by(product_id=product_id).first()
    assert cart_item is not None
    assert cart_item.quantity == 1

def test_add_existing_item_increments_quantity(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test adding an existing product to the cart should increment quantity.
    """
    product_id = test_products["prod1"].id
    # Add first time
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 1})

    # Add second time
    response = client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 2})
    assert response.status_code == 200
    data = response.json()
    assert data["product_id"] == product_id
    assert data["quantity"] == 3 # 1 + 2

    # Verify in DB
    cart_item = db_session.query(CartItem).filter_by(product_id=product_id).first()
    assert cart_item is not None
    assert cart_item.quantity == 3

def test_add_item_with_invalid_quantity(client: TestClient, auth_headers: dict, test_products: dict):
    """
    Test adding a product with quantity 0 or negative should fail.
    """
    product_id = test_products["prod1"].id
    response = client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 0})
    assert response.status_code == 422 # Unprocessable Entity for validation error

    response = client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": -1})
    assert response.status_code == 422

def test_add_non_existent_product(client: TestClient, auth_headers: dict):
    """
    Test adding a non-existent product should return 404.
    """
    response = client.post("/api/cart/items", headers=auth_headers, json={"product_id": "non-existent-prod", "quantity": 1})
    assert response.status_code == 404
    assert "Product not found" in response.json()["message"]

def test_get_empty_cart(client: TestClient, auth_headers: dict):
    """
    Test retrieving an empty cart.
    """
    response = client.get("/api/cart", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["items"] == []
    assert float(data["subtotal"]) == 0.0
    assert float(data["tax"]) == 0.0
    assert float(data["total"]) == 0.0

def test_get_cart_with_items_and_totals(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test retrieving a cart with items and verify server-computed totals.
    """
    product1_id = test_products["prod1"].id
    product2_id = test_products["prod2"].id

    # Add items
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product1_id, "quantity": 2}) # 2 * 10.0 = 20.0
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product2_id, "quantity": 1}) # 1 * 20.0 = 20.0

    response = client.get("/api/cart", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()

    assert len(data["items"]) == 2
    # Assuming a simple tax calculation or no tax for now, based on existing cart.py
    # If cart.py has tax logic, this needs to be updated.
    expected_subtotal = 2 * test_products["prod1"].price + 1 * test_products["prod2"].price
    assert float(data["subtotal"]) == expected_subtotal
    # For now, assuming tax is 0 based on the provided cart.py structure
    assert float(data["tax"]) == 0.0
    assert float(data["total"]) == expected_subtotal

def test_update_cart_item_quantity(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test updating the quantity of an existing item.
    """
    product_id = test_products["prod1"].id
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 1})

    response = client.put(f"/api/cart/items/{product_id}", headers=auth_headers, json={"quantity": 5})
    assert response.status_code == 200
    data = response.json()
    assert data["product_id"] == product_id
    assert data["quantity"] == 5

    cart_item = db_session.query(CartItem).filter_by(product_id=product_id).first()
    assert cart_item is not None # Ensure item exists
    assert cart_item.quantity == 5

def test_update_cart_item_quantity_to_zero_removes_item(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test updating quantity to 0 should remove the item.
    """
    product_id = test_products["prod1"].id
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 1})

    response = client.put(f"/api/cart/items/{product_id}", headers=auth_headers, json={"quantity": 0})
    assert response.status_code == 200
    assert response.json() == {"message": "Item removed from cart"}

    cart_item = db_session.query(CartItem).filter_by(product_id=product_id).first()
    assert cart_item is None

def test_update_non_existent_cart_item(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test updating a non-existent item should return 404, after a cart has been created.
    """
    # First, add an item to create a cart for the user
    product_id_existing = test_products["prod1"].id
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id_existing, "quantity": 1})

    # Now try to update a non-existent item
    response = client.put("/api/cart/items/non-existent-prod", headers=auth_headers, json={"quantity": 1})
    assert response.status_code == 404
    assert "Cart item not found" in response.json()["message"]

def test_remove_cart_item(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test removing an existing item.
    """
    product_id = test_products["prod1"].id
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id, "quantity": 1})

    response = client.delete(f"/api/cart/items/{product_id}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == {"message": "Item removed from cart"}

    cart_item = db_session.query(CartItem).filter_by(product_id=product_id).first()
    assert cart_item is None

def test_remove_non_existent_cart_item(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test removing a non-existent item should return 404, after a cart has been created.
    """
    # First, add an item to create a cart for the user
    product_id_existing = test_products["prod1"].id
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product_id_existing, "quantity": 1})

    # Now try to remove a non-existent item
    response = client.delete("/api/cart/items/non-existent-prod", headers=auth_headers)
    assert response.status_code == 404
    assert "Cart item not found" in response.json()["message"]

def test_clear_cart(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test clearing all items from a cart.
    """
    product1_id = test_products["prod1"].id
    product2_id = test_products["prod2"].id

    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product1_id, "quantity": 1})
    client.post("/api/cart/items", headers=auth_headers, json={"product_id": product2_id, "quantity": 1})

    response = client.delete("/api/cart", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == {"message": "Cart cleared"}

    cart_items = db_session.query(CartItem).all()
    assert len(cart_items) == 0

def test_cart_isolation_between_users(client: TestClient, auth_headers: dict, db_session: Session, test_products: dict):
    """
    Test that carts are isolated between different users.

    Dev auth bypass is locked to a single uid, so the "other user" is
    simulated by inserting their cart rows directly into the DB. The API
    must never let the authenticated user see or mutate those rows.
    """
    other_uid = "phantom-user-2"
    product_id = test_products["prod1"].id

    # Another user has a cart with an item
    other_cart = Cart(user_firebase_uid=other_uid)
    db_session.add(other_cart)
    db_session.flush()
    db_session.add(CartItem(
        cart_id=other_cart.id,
        user_firebase_uid=other_uid,
        product_id=product_id,
        quantity=3,
    ))
    db_session.commit()

    # The authenticated user starts with an empty cart
    response = client.get("/api/cart", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["items"] == []

    # Authenticated user cannot update or delete the other user's item
    response = client.put(f"/api/cart/items/{product_id}", headers=auth_headers, json={"quantity": 2})
    assert response.status_code == 404
    response = client.delete(f"/api/cart/items/{product_id}", headers=auth_headers)
    assert response.status_code == 404

    # The other user's cart still holds the original quantity
    remaining = db_session.query(CartItem).filter(
        CartItem.user_firebase_uid == other_uid
    ).first()
    assert remaining is not None
    assert remaining.quantity == 3