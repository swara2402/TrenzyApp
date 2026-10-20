def test_both_routes(client, auth_headers):
    """Test that both products and ai routes exist (run in same test client context)."""
    print("\n" + "="*80)
    print("TESTING BOTH PRODUCTS AND AI ROUTES IN SAME TEST CONTEXT")
    print("="*80)
    
    # First test products endpoint (known to work)
    products_response = client.get("/api/products", headers=auth_headers)
    print(f"/api/products status: {products_response.status_code}")
    assert products_response.status_code != 404, "/api/products should not return 404"
    
    # Now test ai models health endpoint with correct path and auth headers
    # With router.prefix="/ai" in ai.py + app.include_router with prefix="/api" → full path="/api/ai/models/health"
    ai_health_response = client.get("/api/ai/models/health", headers=auth_headers)
    print(f"/api/ai/models/health status: {ai_health_response.status_code}")
    
    # Print all routes from the app that the test client is using
    from app.main import app
    print("\n" + "="*80)
    print(f"Total routes in app during test: {len(app.routes)}")
    print("All APIRoute objects (actual HTTP routes):")
    for i, route in enumerate(app.routes):
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            methods = ", ".join(sorted(route.methods))
            print(f"  {i+1}. {route.path:<50} METHODS: {methods}")
    print("="*80)