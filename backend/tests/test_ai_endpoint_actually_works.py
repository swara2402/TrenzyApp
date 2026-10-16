"""Simple test to verify the ai endpoint is actually reachable."""

def test_ai_models_health_endpoint(client, auth_headers):
    """Test that the /api/ai/models/health endpoint returns a non-404 response."""
    print("\n" + "="*80)
    print("TESTING IF /api/ai/models/health IS REACHABLE")
    print("="*80)
    
    # First test the known-good products endpoint to verify client is working
    products_resp = client.get("/api/products", headers=auth_headers)
    print(f"/api/products status: {products_resp.status_code}")
    assert products_resp.status_code != 404, "/api/products should work"
    print(f"✓ /api/products works! Status: {products_resp.status_code}")
    
    # Now test our ai endpoint
    ai_health_resp = client.get("/api/ai/models/health", headers=auth_headers)
    print(f"/api/ai/models/health status: {ai_health_resp.status_code}")
    
    # If this is not 404, then our route registration is working!
    if ai_health_resp.status_code == 404:
        print("✗ /api/ai/models/health returns 404 - route registration still broken")
        # Let's list all routes the test client can see
        print("\nAll routes available in test client:")
        from app.main import app
        for i, route in enumerate(app.routes):
            if hasattr(route, 'path'):
                print(f"  {route.path}")
        assert False, "/api/ai/models/health should not return 404"
    else:
        print(f"✓ /api/ai/models/health works! Status: {ai_health_resp.status_code}")
        print(f"Response content: {ai_health_resp.json()}")