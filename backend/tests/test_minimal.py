def test_health_endpoint(client, auth_headers):
    """Test that the health endpoint works."""
    # Print all registered routes in the test client's app
    from app.main import app
    from app.routes import ai
    print("\nAll registered routes in test client app (all of them!):")
    for i, route in enumerate(app.routes):
        if hasattr(route, 'path'):
            print(f"{i+1}. {route.path} -> {route.name}")
    print(f"\nTotal app routes: {len(app.routes)}")
    
    # Print ai.router's own routes
    print("\nai.router's internal routes:")
    for i, route in enumerate(ai.router.routes):
        if hasattr(route, 'path'):
            print(f"  {i+1}. ai.router path: {route.path} -> {route.name}")
    print(f"Total ai.router routes: {len(ai.router.routes)}")
    print(f"ai.router.prefix: {ai.router.prefix}")
    
    response = client.get("/api/health", headers=auth_headers)
    print(f"Health endpoint status: {response.status_code}")
    assert response.status_code == 200

def test_ai_models_health(client, auth_headers):
    """Test that the ai models health endpoint works."""
    # Test the correct path after adding prefix="/api" to ai.router
    path = "/api/ai/models/health"
    response = client.get(path, headers=auth_headers)
    print(f"GET {path} -> {response.status_code}")
    assert response.status_code == 200, f"Failed to reach {path}"
    print(f"Success! {path} is the correct path")