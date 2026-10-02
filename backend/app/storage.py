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


def save_bytes(data: bytes, ext: str, *, subdir: str = "") -> str:
    """Persist bytes and return the public URL."""
    ext = ext if ext.startswith(".") else f".{ext}"
    key = _new_key(ext.lower())
    if subdir:
        key = f"{subdir.strip('/')}/{key}"

    if STORAGE_BACKEND == "s3":
        return _save_s3(data, key)
    return _save_local(data, key)


def _save_local(data: bytes, key: str) -> str:
    dest = UPLOAD_DIR / key
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return f"{UPLOAD_BASE_URL}/{key}"


def _save_s3(data: bytes, key: str) -> str:
    if not S3_BUCKET:
        raise StorageError("S3_BUCKET is required when STORAGE_BACKEND=s3")
    try:
        import boto3
        from botocore.client import Config
    except ImportError as exc:
        raise StorageError("boto3 is required for S3 storage") from exc

    object_key = f"{S3_PREFIX}/{key}" if S3_PREFIX else key
    client_kwargs = {"region_name": S3_REGION}
    if S3_ENDPOINT_URL:
        client_kwargs["endpoint_url"] = S3_ENDPOINT_URL
        client_kwargs["config"] = Config(signature_version="s3v4")

    client = boto3.client("s3", **client_kwargs)
    extra = {"ContentType": _guess_content_type(key)}
    client.put_object(Bucket=S3_BUCKET, Key=object_key, Body=data, **extra)

    if S3_PUBLIC_BASE_URL:
        return f"{S3_PUBLIC_BASE_URL}/{object_key}"
    return f"https://{S3_BUCKET}.s3.{S3_REGION}.amazonaws.com/{object_key}"


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
