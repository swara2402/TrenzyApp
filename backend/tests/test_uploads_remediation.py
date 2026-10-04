"""Tests for file upload validation (magic bytes, extensions, size limits, traversal)."""
from __future__ import annotations

import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import User


def test_upload_valid_jpeg_avatar(client: TestClient, db_session: Session, auth_headers):
    """Valid JPEG with correct magic bytes succeeds."""
    uid = "test-user-1"
    headers = auth_headers

    user = User(firebase_uid=uid, email="upload1@example.com", name="Upload User")
    db_session.add(user)
    db_session.commit()

    # Valid JPEG header: \xff\xd8\xff\xe0
    jpeg_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00" + b"dummycontent"
    files = {"file": ("avatar.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")}

    res = client.post("/api/uploads/avatar", files=files, headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert "avatar_url" in data
    assert "avatars/" in data["avatar_url"]


def test_upload_magic_bytes_mismatch_rejected(client: TestClient, db_session: Session, auth_headers):
    """Text/HTML file masquerading with .jpg extension is rejected."""
    uid = "test-user-1"
    headers = auth_headers

    user = User(firebase_uid=uid, email="upload2@example.com", name="Upload User 2")
    db_session.add(user)
    db_session.commit()

    fake_jpeg = b"<script>alert('xss')</script>"
    files = {"file": ("malicious.jpg", io.BytesIO(fake_jpeg), "image/jpeg")}

    res = client.post("/api/uploads/avatar", files=files, headers=headers)
    assert res.status_code == 400
    assert "File content does not match extension" in str(res.json())


def test_upload_disallowed_extension_rejected(client: TestClient, db_session: Session, auth_headers):
    """Disallowed extension (e.g. .svg or .exe) is rejected immediately."""
    uid = "test-user-1"
    headers = auth_headers

    user = User(firebase_uid=uid, email="upload3@example.com", name="Upload User 3")
    db_session.add(user)
    db_session.commit()

    files = {"file": ("script.svg", io.BytesIO(b"<svg></svg>"), "image/svg+xml")}
    res = client.post("/api/uploads/avatar", files=files, headers=headers)
    assert res.status_code == 400
    assert "not allowed" in str(res.json())
