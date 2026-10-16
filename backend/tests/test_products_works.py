
def test_products_endpoint_exists(client):
    """Test that the /api/products endpoint exists (to confirm included routers work)."""
    response = client.get("/api/products")
    # Should return 200 or 401, but not 404!
    assert response.status_code != 404, "/api/products should not return 404 (included router works)"
    print(f"✓ /api/products returned status code {response.status_code} (not 404, so included router works!)")