"""Tests for authentication endpoints (/api/auth/*).

Covers:
- Input validation on login, signup, reset-password
- Authenticated user profile retrieval (/api/auth/me)
- Token verification and failure modes
- Mocked Firebase Identity Toolkit integration for login, signup, and password reset
"""

import pytest


class TestLoginValidation:
    """Test validation on /api/auth/login."""

    def test_login_missing_fields(self, client):
        """Should return 422 when body is empty or missing required fields."""
        response = client.post("/api/auth/login", json={})
        assert response.status_code == 422

    def test_login_empty_email(self, client):
        """Should return 400 when email is empty string."""
        response = client.post(
            "/api/auth/login",
            json={"email": "", "password": "password123"},
        )
        assert response.status_code == 400
        assert "Email is required" in response.json()["message"]

    def test_login_empty_password(self, client):
        """Should return 400 when password is empty string."""
        response = client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": ""},
        )
        assert response.status_code == 400
        assert "Password is required" in response.json()["message"]


class TestSignupValidation:
    """Test validation on /api/auth/signup."""

    def test_signup_missing_fields(self, client):
        """Should return 422 when required fields are missing."""
        response = client.post("/api/auth/signup", json={"email": "test@example.com"})
        assert response.status_code == 422

    def test_signup_empty_email(self, client):
        """Should return 400 (ValidationError) when email is whitespace/empty."""
        response = client.post(
            "/api/auth/signup",
            json={"name": "User", "email": "", "password": "securePassword123"},
        )
        assert response.status_code == 400

    def test_signup_short_password(self, client):
        """Should return 400 (ValidationError) when password is shorter than 6 characters."""
        response = client.post(
            "/api/auth/signup",
            json={"name": "User", "email": "test@example.com", "password": "123"},
        )
        assert response.status_code == 400


class TestPasswordResetValidation:
    """Test validation on /api/auth/reset-password."""

    def test_reset_password_missing_email(self, client):
        """Should return 422 when email field is missing."""
        response = client.post("/api/auth/reset-password", json={})
        assert response.status_code == 422

    def test_reset_password_empty_email(self, client):
        """Should return 400 when email is empty string."""
        response = client.post("/api/auth/reset-password", json={"email": "   "})
        assert response.status_code == 400


class TestCurrentUserEndpoint:
    """Test /api/auth/me."""

    def test_me_without_auth(self, client):
        """Should return 401 when no token is provided."""
        response = client.get("/api/auth/me")
        assert response.status_code == 401

    def test_me_with_invalid_token(self, client):
        """Should return 401 when an unauthorized/malformed dev token is provided."""
        response = client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer dev-token-baduser:invalidsig"},
        )
        assert response.status_code == 401

    def test_me_with_valid_auth(self, client, auth_headers):
        """Should return the synced user profile for a valid token."""
        response = client.get("/api/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert data["user"]["firebaseUid"] == "test-user-1"


class TestGoogleLoginEndpoint:
    """Test /api/auth/google-login."""

    def test_google_login_without_auth(self, client):
        """Should return 401 when called without credentials."""
        response = client.post("/api/auth/google-login")
        assert response.status_code == 401

    def test_google_login_with_valid_auth(self, client, auth_headers):
        """Should sync and return the user profile."""
        response = client.post("/api/auth/google-login", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert data["user"]["firebaseUid"] == "test-user-1"


class TestMockedFirebaseAuthFlows:
    """Test login and signup flows by mocking Firebase Identity Toolkit calls."""

    def test_successful_login(self, client, monkeypatch):
        """Should return token and user when Firebase auth succeeds."""
        async def fake_firebase_post(path, payload):
            if "signInWithPassword" in path:
                return {
                    "idToken": "fake-id-token",
                    "localId": "firebase-uid-456",
                    "email": "user@example.com",
                }
            if "lookup" in path:
                return {"users": [{"displayName": "Test User"}]}
            return {}

        monkeypatch.setattr("app.routes.auth._firebase_post", fake_firebase_post)
        monkeypatch.setattr(
            "app.routes.auth._generate_custom_token",
            lambda uid: f"custom-token-for-{uid}",
        )

        response = client.post(
            "/api/auth/login",
            json={"email": "user@example.com", "password": "password123"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["token"] == "custom-token-for-firebase-uid-456"
        assert data["user"]["email"] == "user@example.com"
        assert data["user"]["name"] == "Test User"

    def test_successful_signup(self, client, monkeypatch):
        """Should create user, persona, preferences, and return token."""
        async def fake_firebase_post(path, payload):
            if "signUp" in path:
                return {
                    "idToken": "fake-id-token",
                    "localId": "new-user-789",
                    "email": "newbie@example.com",
                }
            if "update" in path:
                return {
                    "idToken": "fake-id-token-updated",
                    "localId": "new-user-789",
                }
            return {}

        monkeypatch.setattr("app.routes.auth._firebase_post", fake_firebase_post)
        monkeypatch.setattr(
            "app.routes.auth._generate_custom_token",
            lambda uid: f"custom-token-for-{uid}",
        )

        response = client.post(
            "/api/auth/signup",
            json={
                "name": "Newbie",
                "email": "newbie@example.com",
                "password": "strongPassword123",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["token"] == "custom-token-for-new-user-789"
        assert data["user"]["email"] == "newbie@example.com"
        assert data["user"]["name"] == "Newbie"

    def test_successful_reset_password(self, client, monkeypatch):
        """Should call Firebase OOB code generator and return status sent."""
        called_with = []

        async def fake_firebase_post(path, payload):
            called_with.append((path, payload))
            return {}

        monkeypatch.setattr("app.routes.auth._firebase_post", fake_firebase_post)

        response = client.post(
            "/api/auth/reset-password",
            json={"email": "resetme@example.com"},
        )
        assert response.status_code == 200
        assert response.json() == {"status": "sent"}
        assert len(called_with) == 1
        assert called_with[0][1]["email"] == "resetme@example.com"
