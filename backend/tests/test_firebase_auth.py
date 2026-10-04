import io

import pytest

from app import firebase_auth


@pytest.fixture(autouse=True)
def reset_firebase_state(monkeypatch):
    monkeypatch.setattr(firebase_auth, "_init_attempted", False)
    monkeypatch.setattr(firebase_auth, "_firebase_initialized", False)
    monkeypatch.setattr(firebase_auth, "DEV_AUTH_BYPASS", False)
    monkeypatch.setattr(firebase_auth, "DEV_AUTH_UID", "")
    monkeypatch.setattr(firebase_auth, "DEV_AUTH_SECRET", "")


def test_init_firebase_admin_missing_file_fails_closed(monkeypatch):
    """A configured-but-missing service-account file must NOT initialize Firebase.

    Fail-closed by design: no implicit fallback paths are searched, and the
    error is logged so operators notice the misconfiguration.
    """
    requested_path = "/tmp/missing-service-account.json"

    monkeypatch.setattr(firebase_auth, "FIREBASE_SERVICE_ACCOUNT_FILE", requested_path)
    monkeypatch.setattr(firebase_auth, "FIREBASE_SERVICE_ACCOUNT_JSON", "")
    monkeypatch.setattr(firebase_auth.firebase_admin, "_apps", [])
    monkeypatch.setattr("app.firebase_auth.os.path.exists", lambda path: False)

    firebase_auth.init_firebase_admin()

    assert firebase_auth._firebase_initialized is False
    assert firebase_auth._init_attempted is True


def test_init_firebase_admin_uses_valid_file(monkeypatch):
    """A valid service-account file initializes the Admin SDK."""
    requested_path = "/tmp/fake-service-account.json"

    monkeypatch.setattr(firebase_auth, "FIREBASE_SERVICE_ACCOUNT_FILE", requested_path)
    monkeypatch.setattr(firebase_auth, "FIREBASE_SERVICE_ACCOUNT_JSON", "")
    monkeypatch.setattr(firebase_auth.firebase_admin, "_apps", [])

    monkeypatch.setattr(
        "app.firebase_auth.os.path.exists", lambda path: path == requested_path
    )
    monkeypatch.setattr("app.firebase_auth.os.path.getsize", lambda path: 100)

    def fake_open(path, mode="r", encoding=None):
        if path == requested_path:
            return io.StringIO('{"type": "service_account"}')
        raise FileNotFoundError(path)

    monkeypatch.setattr("builtins.open", fake_open)

    class DummyCred:
        pass

    monkeypatch.setattr(
        firebase_auth.firebase_admin.credentials,
        "Certificate",
        lambda path: DummyCred(),
    )
    monkeypatch.setattr(
        firebase_auth.firebase_admin,
        "initialize_app",
        lambda cred: None,
    )

    firebase_auth.init_firebase_admin()

    assert firebase_auth._firebase_initialized is True
