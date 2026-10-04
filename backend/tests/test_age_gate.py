"""Regression tests for authenticated database-user age enforcement."""

from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app import firebase_auth
from app.auth_deps import get_current_db_user


class _Query:
    def __init__(self, user):
        self.user = user

    def filter(self, *_args):
        return self

    def first(self):
        return self.user


class _DB:
    def __init__(self, user):
        self.user = user

    def query(self, *_args):
        return _Query(self.user)


def _request():
    return SimpleNamespace(url=SimpleNamespace(path="/api/products"))


def test_get_current_db_user_requires_date_of_birth(monkeypatch):
    monkeypatch.setattr(
        firebase_auth,
        "verify_token_string",
        lambda _token: {"uid": "user-1"},
    )

    user = SimpleNamespace(firebase_uid="user-1", date_of_birth=None)

    with pytest.raises(HTTPException) as exc:
        get_current_db_user(
            request=_request(),
            token="valid-token",
            db=_DB(user),
        )

    assert exc.value.status_code == 403
    assert exc.value.detail == "AGE_VERIFICATION_REQUIRED"


def test_get_current_db_user_allows_verified_user(monkeypatch):
    monkeypatch.setattr(
        firebase_auth,
        "verify_token_string",
        lambda _token: {"uid": "user-1"},
    )

    user = SimpleNamespace(
        firebase_uid="user-1",
        date_of_birth="2000-01-01",
    )

    result = get_current_db_user(
        request=_request(),
        token="valid-token",
        db=_DB(user),
    )

    assert result is user
