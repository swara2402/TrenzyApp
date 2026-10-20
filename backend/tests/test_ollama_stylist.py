"""AI Stylist beta contract tests.

The launch contract intentionally uses the local catalog-backed stylist and
must not make outbound LLM calls, even if optional Ollama environment values
are present.
"""
from datetime import date
import os
from unittest.mock import patch

import pytest
from app.models import User


@pytest.fixture(autouse=True)
def ensure_test_profile(db_session):
    """Exercise authenticated AI routes with a realistic age-verified profile."""
    user = db_session.query(User).filter_by(firebase_uid="test-user-1").first()
    if user is None:
        db_session.add(
            User(
                firebase_uid="test-user-1",
                name="Beta Test User",
                username="beta-test-user",
                date_of_birth=date(2000, 1, 1),
            )
        )
        db_session.commit()


def test_stylist_chat_uses_local_fallback(client, auth_headers, monkeypatch):
    monkeypatch.delenv("OLLAMA_BASE_URL", raising=False)
    response = client.post(
        "/api/ai/stylist/chat",
        json={"message": "What should I wear to a wedding?", "conversation_id": None},
        headers=auth_headers,
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["conversation_id"]
    assert isinstance(data["message"], str) and data["message"].strip()
    assert "mentioned_products" in data


def test_health_reports_ollama_unconfigured(client, auth_headers, monkeypatch):
    monkeypatch.delenv("OLLAMA_BASE_URL", raising=False)
    response = client.get("/api/ai/models/health", headers=auth_headers)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["external_ai_services"]["ollama"]["configured"] is False
    assert data["external_ai_services"]["ollama"]["status"] == "unavailable"


@patch("requests.post")
def test_stylist_does_not_call_remote_llm(mock_post, client, auth_headers, monkeypatch):
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://localhost:11434")
    monkeypatch.setenv("OLLAMA_MODEL", "llama3.2")
    response = client.post(
        "/api/ai/stylist/chat",
        json={"message": "Suggest a casual college outfit", "conversation_id": None},
        headers=auth_headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["message"].strip()
    mock_post.assert_not_called()
