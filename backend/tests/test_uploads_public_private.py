"""Tests for the public/private upload split.

Avatars and post attachments are public (served without auth via
``/uploads/public/...``). Wardrobe images are private (served only to the owner
through ``/api/uploads/private/...``).
"""
from __future__ import annotations

import io

from fastapi.testclient import TestClient

# Minimal valid JPEG (magic bytes \xff\xd8\xff).
JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00" + b"payload"


def _jpeg_files(name: str = "pic.jpg"):
    return {"file": (name, io.BytesIO(JPEG), "image/jpeg")}


def test_post_image_is_publicly_served(client: TestClient, auth_headers):
    res = client.post("/api/uploads/post-image", files=_jpeg_files(), headers=auth_headers)
    assert res.status_code == 200, res.text
    url = res.json()["image_url"]
    assert url.startswith("/uploads/public/posts/"), url

    # Public: fetchable with NO auth header.
    fetched = client.get(url)
    assert fetched.status_code == 200, fetched.text
    assert fetched.content == JPEG


def test_avatar_is_publicly_served(client: TestClient, auth_headers):
    res = client.post("/api/uploads/avatar", files=_jpeg_files(), headers=auth_headers)
    assert res.status_code == 200, res.text
    url = res.json()["avatar_url"]
    assert url.startswith("/uploads/public/avatars/"), url
    assert client.get(url).status_code == 200


def test_wardrobe_image_requires_owner_auth(client: TestClient, auth_headers):
    res = client.post("/api/uploads/image", files=_jpeg_files(), headers=auth_headers)
    assert res.status_code == 200, res.text
    url = res.json()["image_url"]
    assert url.startswith("/api/uploads/private/test-user-1/images/"), url

    # Owner can fetch it.
    assert client.get(url, headers=auth_headers).status_code == 200
    # Anonymous cannot.
    assert client.get(url).status_code in (401, 403)
