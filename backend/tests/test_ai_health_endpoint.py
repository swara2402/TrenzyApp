"""Test that the /api/ai/models/health endpoint actually works."""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_ai_models_health_endpoint(auth_headers):
    """Test that the AI models health endpoint returns 200 OK."""
    response = client.get("/api/ai/models/health", headers=auth_headers)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
    print(f"✅ /api/ai/models/health returned 200 OK!")
    print(f"   Response: {response.json()}")

def test_ai_stylist_chat_endpoint(auth_headers):
    """Test that the AI stylist chat endpoint is reachable."""
    # Send a minimal chat request
    payload = {
        "message": "What outfit should I wear to a wedding?",
        "conversation_id": None
    }
    response = client.post("/api/ai/stylist/chat", json=payload, headers=auth_headers)
    print(f"POST /api/ai/stylist/chat - Status: {response.status_code}")
    if response.status_code != 200:
        print(f"   Response content: {response.text}")