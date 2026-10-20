"""Production-ready upload storage abstraction.

Supports:
- local filesystem (default, development + simple deploys)
- S3-compatible object storage when STORAGE_BACKEND=s3

Never expose raw disk paths to clients; always return public URLs.
"""
from __future__ import annotations

import logging
import os
import uuid
from pathlib import Path
from typing import BinaryIO

logger = logging.getLogger(__name__)

STORAGE_BACKEND = os.getenv("STORAGE_BACKEND", "local").lower().strip()
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "uploads"))
UPLOAD_BASE_URL = os.getenv("UPLOAD_BASE_URL", "http://localhost:8000/uploads").rstrip("/")

# S3 settings (only used when STORAGE_BACKEND=s3)
S3_BUCKET = os.getenv("S3_BUCKET", "")
S3_REGION = os.getenv("S3_REGION", "us-east-1")
S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL", "")  # optional (MinIO, R2, etc.)
S3_PUBLIC_BASE_URL = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
S3_PREFIX = os.getenv("S3_PREFIX", "uploads").strip("/")


class StorageError(Exception):
    pass


def _new_key(ext: str) -> str:
    return f"{uuid.uuid4().hex}{ext}"


def save_bytes(data: bytes, ext: str, *, subdir: str = "", public: bool = True) -> str:
    """Persist bytes and return the URL clients should store.

    Args:
        data: Raw file bytes.
        ext: File extension (with or without a leading dot).
        subdir: Optional path segment(s) nested under the public/private scope,
            e.g. ``"avatars"`` or ``"<uid>/images"``.
        public: When ``True`` the file is written under the public scope and is
            served without authentication (e.g. avatars, post attachments).
            When ``False`` it is written under the private scope and is only
            served through the authenticated uploads route (e.g. wardrobe
            images).

    Returns:
        For local storage, a *relative* URL (e.g. ``/uploads/public/...`` or
        ``/api/uploads/private/...``) so the client resolves it against the
        configured API host. For S3 public files, an absolute object URL. S3
        private files also return a relative authenticated URL.
    """
    ext = ext if ext.startswith(".") else f".{ext}"
    key = _new_key(ext.lower())
    scope = "public" if public else "private"
    rel = f"{scope}/{subdir.strip('/')}/{key}" if subdir.strip("/") else f"{scope}/{key}"

    if STORAGE_BACKEND == "s3":
        _save_s3(data, rel)
        if public:
            object_key = f"{S3_PREFIX}/{rel}" if S3_PREFIX else rel
            if S3_PUBLIC_BASE_URL:
                return f"{S3_PUBLIC_BASE_URL}/{object_key}"
            return f"https://{S3_BUCKET}.s3.{S3_REGION}.amazonaws.com/{object_key}"
        return f"/api/uploads/private/{rel[len('private/'):]}"

    dest = UPLOAD_DIR / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    if public:
        return f"/uploads/{rel.lstrip('/')}"
    return f"/api/uploads/private/{rel[len('private/'):]}"


def load_bytes(rel_key: str) -> bytes:
    """Load a stored object by its scope-relative key (used by the private route)."""
    rel = rel_key.strip("/")
    if STORAGE_BACKEND == "s3":
        if not S3_BUCKET:
            raise StorageError("S3_BUCKET is required when STORAGE_BACKEND=s3")
        try:
            import boto3
            from botocore.client import Config
        except ImportError as exc:
            raise StorageError("boto3 is required for S3 storage") from exc
        object_key = f"{S3_PREFIX}/{rel}" if S3_PREFIX else rel
        client_kwargs = {"region_name": S3_REGION}
        if S3_ENDPOINT_URL:
            client_kwargs["endpoint_url"] = S3_ENDPOINT_URL
            client_kwargs["config"] = Config(signature_version="s3v4")
        client = boto3.client("s3", **client_kwargs)
        return client.get_object(Bucket=S3_BUCKET, Key=object_key)["Body"].read()

    path = UPLOAD_DIR / rel
    if not path.is_file():
        raise StorageError(f"Object not found: {rel}")
    return path.read_bytes()


def _save_s3(data: bytes, rel_key: str) -> None:
    if not S3_BUCKET:
        raise StorageError("S3_BUCKET is required when STORAGE_BACKEND=s3")
    try:
        import boto3
        from botocore.client import Config
    except ImportError as exc:
        raise StorageError("boto3 is required for S3 storage") from exc

    object_key = f"{S3_PREFIX}/{rel_key}" if S3_PREFIX else rel_key
    client_kwargs = {"region_name": S3_REGION}
    if S3_ENDPOINT_URL:
        client_kwargs["endpoint_url"] = S3_ENDPOINT_URL
        client_kwargs["config"] = Config(signature_version="s3v4")

    client = boto3.client("s3", **client_kwargs)
    extra = {"ContentType": _guess_content_type(rel_key)}
    client.put_object(Bucket=S3_BUCKET, Key=object_key, Body=data, **extra)


def _guess_content_type(key: str) -> str:
    lower = key.lower()
    if lower.endswith(".png"):
        return "image/png"
    if lower.endswith(".gif"):
        return "image/gif"
    if lower.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


def backend_name() -> str:
    return STORAGE_BACKEND
