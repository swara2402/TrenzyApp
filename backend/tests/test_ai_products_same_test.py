def test_both_endpoints_work(client, auth_headers, db_session):
    """Test that both products (known good) and ai endpoints return non-404."""
    print("\n" + "="*80)
    print("TESTING BOTH PRODUCTS AND AI ENDPOINTS IN SAME TEST CONTEXT")
    print("="*80)
    
    # The chat route needs a real, age-verified profile, just as production does.
    from datetime import date
    from app.models import User
    db_session.add(User(firebase_uid="test-user-1", name="Test User", username="test-user-route-check", date_of_birth=date(2000, 1, 1)))
    db_session.commit()

    # First test products endpoint (should work, not 404)
    products_response = client.get("/api/products")
    print(f"/api/products status: {products_response.status_code}")
    assert products_response.status_code != 404, "/api/products should NOT return 404"
    print(f"✓ products endpoint works! Status: {products_response.status_code}")
    
    # Now test ai models health endpoint - this is the one we think is 404
    ai_health_response = client.get("/api/ai/models/health", headers=auth_headers)
    print(f"/api/ai/models/health status: {ai_health_response.status_code}")
    # If this is NOT 404, then the router is registered correctly!
    assert ai_health_response.status_code != 404, "/api/ai/models/health should NOT return 404"
    print(f"✓ ai endpoint works! Status: {ai_health_response.status_code}")
    
    # Now test the actual chat endpoint
    chat_response = client.post(
        "/api/ai/stylist/chat",
        json={"message": "test message", "conversation_id": None},
        headers=auth_headers
    )
    print(f"/api/ai/stylist/chat status: {chat_response.status_code}")
    assert chat_response.status_code != 404, "/api/ai/stylist/chat should NOT return 404"
    print(f"✓ chat endpoint works! Status: {chat_response.status_code}")