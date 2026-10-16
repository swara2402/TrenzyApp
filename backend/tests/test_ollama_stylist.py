"""Ollama AI Stylist integration tests.

Verifies the end-to-end Ollama integration for the AI Stylist feature.
"""
import pytest
import os
import requests
from unittest.mock import patch, MagicMock
from app.main import app

# Debug: Print all registered routes to check endpoint paths
from app.main import app as main_app
print(f"\nTotal routes in main app: {len(main_app.routes)}")
print("\nAll main app routes that are APIRoute (real HTTP routes), including any /api/products... routes:")
for i, route in enumerate(main_app.routes):
    route_type = type(route).__name__
    path = getattr(route, 'path', 'NO PATH')
    if "/products" in path:
        print(f"  FOUND products route: {path}")
print()

# Also print ai.router's routes to confirm they exist
from app.routes import ai
print(f"\nai.router has {len(ai.router.routes)} routes:")
for i, route in enumerate(ai.router.routes):
    route_type = type(route).__name__
    path = getattr(route, 'path', 'NO PATH')
    print(f"  {i+1}. [{route_type}] /api/ai{path}")
print()


def test_ollama_not_configured_uses_fallback(client, auth_headers, db_session):
    """Test that when Ollama is not configured, the chat endpoint falls back to rule-based responses."""
    # First verify we can reach the products endpoint (known good route)
    products_resp = client.get("/api/products", headers=auth_headers)
    print(f"Products endpoint status: {products_resp.status_code}")
    
    # Ensure no Ollama configuration is set
    if "OLLAMA_BASE_URL" in os.environ:
        del os.environ["OLLAMA_BASE_URL"]
    
    payload = {"message": "What should I wear to a wedding?", "conversation_id": None}
    response = client.post("/api/ai/stylist/chat", json=payload, headers=auth_headers)
    
    # Should always return 200 OK even with fallback
    assert response.status_code == 200
    data = response.json()
    assert "response" in data
    assert "conversation_id" in data
    assert len(data["response"]) > 0  # Should have a fallback response


def test_ollama_health_status_when_not_configured(client, auth_headers):
    """Test that the health endpoint correctly reports Ollama as unconfigured when no URL is set."""
    if "OLLAMA_BASE_URL" in os.environ:
        del os.environ["OLLAMA_BASE_URL"]
    
    response = client.get("/api/ai/models/health", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    
    assert "external_ai_services" in data
    assert "ollama" in data["external_ai_services"]
    assert data["external_ai_services"]["ollama"]["configured"] is False
    assert data["external_ai_services"]["ollama"]["status"] == "unavailable"
    assert data["external_ai_services"]["ollama"]["model"] is None


def test_ollama_health_status_when_configured(client, auth_headers):
    """Test that the health endpoint correctly reports Ollama configuration when set."""
    os.environ["OLLAMA_BASE_URL"] = "http://localhost:11434"
    os.environ["OLLAMA_MODEL"] = "llama3.2"
    
    # Reload config to pick up new env vars
    from importlib import reload
    from app import config
    reload(config)
    
    response = client.get("/api/ai/models/health", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    
    assert "external_ai_services" in data
    assert "ollama" in data["external_ai_services"]
    assert data["external_ai_services"]["ollama"]["configured"] is True
    assert data["external_ai_services"]["ollama"]["status"] == "available"
    assert data["external_ai_services"]["ollama"]["model"] == "llama3.2"
    assert data["external_ai_services"]["ollama"]["base_url"] == "http://localhost:11434"
    
    # Cleanup
    del os.environ["OLLAMA_BASE_URL"]
    del os.environ["OLLAMA_MODEL"]


@patch("requests.post")
def test_ollama_api_call_success(mock_post, client, auth_headers, db_session):
    """Test that when Ollama is configured and reachable, it successfully calls the Ollama API."""
    os.environ["OLLAMA_BASE_URL"] = "http://localhost:11434"
    os.environ["OLLAMA_MODEL"] = "llama3.2"
    
    # Mock the Ollama API response
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "message": {
            "content": "For a summer wedding, I recommend a lightweight linen suit in navy or light blue. It's breathable and looks elegant."
        }
    }
    mock_post.return_value = mock_response
    
    # Reload config
    from importlib import reload
    from app import config
    reload(config)
    
    payload = {"message": "What should I wear to a summer wedding?", "conversation_id": None}
    response = client.post("/api/ai/stylist/chat", json=payload, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert "response" in data
    assert "summer wedding" in data["response"].lower() or "wedding" in data["response"].lower()
    
    # Verify that requests.post was called with the correct Ollama endpoint
    mock_post.assert_called_once()
    call_args = mock_post.call_args
    assert "localhost:11434/api/chat" in call_args[0][0]
    
    # Cleanup
    del os.environ["OLLAMA_BASE_URL"]
    del os.environ["OLLAMA_MODEL"]


@patch("requests.post")
def test_ollama_api_call_failure_falls_back(mock_post, client, auth_headers, db_session):
    """Test that when Ollama API fails, it gracefully falls back to the rule-based response."""
    os.environ["OLLAMA_BASE_URL"] = "http://localhost:11434"
    os.environ["OLLAMA_MODEL"] = "llama3.2"
    
    # Mock an Ollama API failure
    mock_post.side_effect = requests.exceptions.RequestException("Ollama server unreachable")
    
    # Reload config
    from importlib import reload
    from app import config
    reload(config)
    
    payload = {"message": "What should I wear to a wedding?", "conversation_id": None}
    response = client.post("/api/ai/stylist/chat", json=payload, headers=auth_headers)
    
    # Should still return 200 OK with fallback response
    assert response.status_code == 200
    data = response.json()
    assert "response" in data
    assert len(data["response"]) > 0
    
    # Cleanup
    del os.environ["OLLAMA_BASE_URL"]
    del os.environ["OLLAMA_MODEL"]


@patch("requests.post")
def test_ollama_api_timeout_falls_back(mock_post, client, auth_headers, db_session):
    """Test that Ollama API timeout triggers fallback to rule-based response."""
    os.environ["OLLAMA_BASE_URL"] = "http://localhost:11434"
    os.environ["OLLAMA_MODEL"] = "llama3.2"
    
    # Mock a timeout
    mock_post.side_effect = requests.exceptions.Timeout("Ollama server timed out")
    
    # Reload config
    from importlib import reload
    from app import config
    reload(config)
    
    payload = {"message": "What's a good casual outfit?", "conversation_id": None}
    response = client.post("/api/ai/stylist/chat", json=payload, headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert "response" in data
    assert len(data["response"]) > 0
    
    # Cleanup
    del os.environ["OLLAMA_BASE_URL"]
    del os.environ["OLLAMA_MODEL"]