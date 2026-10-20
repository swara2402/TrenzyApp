"""File upload endpoint for user profile images, post attachments, and wardrobe.

Accepts multipart file uploads, validates file extension and magic bytes, and
persists through the storage abstraction (local disk or S3).

Privacy model:
- Public uploads (avatars, post attachments) are stored under the public scope
  and served without authentication (mounted at ``/uploads/public``).
- Private uploads (wardrobe images) are stored under the private scope and are
  only served through the authenticated route in this module.
"""
from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import FileResponse, Response
from sqlalchemy.orm import Session

from ..config import UPLOAD_DIR
from ..storage import save_bytes, load_bytes, backend_name, StorageError
from ..db import get_session
from ..auth_deps import get_current_user
from ..models import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/uploads", tags=["uploads"])

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

# Magic bytes for validating file content matches extension
_MAGIC_BYTES = {
    b'\xff\xd8\xff': '.jpg',
    b'\x89PNG': '.png',
    b'GIF8': '.gif',
    b'RIFF': '.webp',
}


def _safe_uid(uid: str) -> str:
    safe = "".join(c for c in uid if c.isalnum() or c in "-_")[:64]
    return safe or "user"


async def _read_and_validate(file: UploadFile) -> tuple[bytes, str]:
    """Validate extension, size, and magic bytes; return (contents, ext)."""
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type {ext!r} not allowed. Supported formats: {sorted(ALLOWED_EXTENSIONS)}",
        )

    # Stream-read with 5MB hard limit
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await file.read(64 * 1024)
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_FILE_SIZE:
            raise HTTPException(status_code=400, detail="File too large (max 5MB)")
        chunks.append(chunk)

    if total == 0:
        raise HTTPException(status_code=400, detail="Uploaded file cannot be empty")

    contents = b"".join(chunks)

    # Validate magic bytes
    detected_ext = None
    for magic, ext_check in _MAGIC_BYTES.items():
        if contents.startswith(magic):
            detected_ext = ext_check
            break

    jpeg_pair = {".jpg", ".jpeg"}
    if detected_ext in jpeg_pair and ext in jpeg_pair:
        detected_ext = ext

    if detected_ext != ext:
        logger.warning(
            "Upload rejected: Magic bytes mismatch (detected=%s, declared=%s)",
            detected_ext, ext,
        )
        raise HTTPException(status_code=400, detail=f"File content does not match extension {ext}")

    return contents, ext


async def _store_upload(
    file: UploadFile, uid: str, subfolder: str, *, public: bool
) -> str:
    """Validate and persist an upload, returning the URL to store on the object."""
    contents, ext = await _read_and_validate(file)
    safe_uid = _safe_uid(uid)
    subdir = subfolder if public else f"{safe_uid}/{subfolder}"
    try:
        return save_bytes(contents, ext, subdir=subdir, public=public)
    except StorageError as exc:
        logger.error("Upload storage failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to store upload")


@router.post("/avatar")
async def upload_avatar(
    file: UploadFile,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, str]:
    """Upload user avatar (public) and update profile."""
    uid = user.get("uid") or user.get("firebase_uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    avatar_url = await _store_upload(file, str(uid), "avatars", public=True)

    db_user = session.query(User).filter(User.firebase_uid == str(uid)).first()
    if db_user:
        db_user.avatar_url = avatar_url
        session.commit()

    return {"avatar_url": avatar_url, "avatarUrl": avatar_url}


@router.post("/image")
async def upload_image(
    file: UploadFile,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, str]:
    """Upload a private image (wardrobe items). Served only to the owner."""
    uid = user.get("uid") or user.get("firebase_uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    image_url = await _store_upload(file, str(uid), "images", public=False)
    return {"image_url": image_url, "imageUrl": image_url}


@router.post("/post-image")
async def upload_post_image(
    file: UploadFile,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, str]:
    """Upload a public post attachment, viewable by all users in the feed."""
    uid = user.get("uid") or user.get("firebase_uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    image_url = await _store_upload(file, str(uid), "posts", public=True)
    return {"image_url": image_url, "imageUrl": image_url}


@router.get("/storage-info")
async def storage_info(user: dict = Depends(get_current_user)):
    """Return active storage backend (local|s3) for ops visibility."""
    return {"backend": backend_name()}


@router.get("/private/{uid}/{subfolder}/{filename}")
async def get_private_upload(
    uid: str,
    subfolder: str,
    filename: str,
    user: dict = Depends(get_current_user),
):
    """Serve a user's private upload only to that same authenticated user."""
    current_uid = str(user.get("uid") or user.get("firebase_uid") or "")
    if not current_uid or current_uid != uid:
        raise HTTPException(status_code=403, detail="You do not have access to this file.")

    if subfolder not in {"images"}:
        raise HTTPException(status_code=404, detail="File not found.")

    if Path(filename).name != filename or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Invalid filename.")

    rel_key = f"private/{_safe_uid(uid)}/{subfolder}/{filename}"
    try:
        data = load_bytes(rel_key)
    except StorageError:
        raise HTTPException(status_code=404, detail="File not found.")
    return Response(content=data, media_type=_content_type(filename))


def _content_type(filename: str) -> str:
    lower = filename.lower()
    if lower.endswith(".png"):
        return "image/png"
    if lower.endswith(".gif"):
        return "image/gif"
    if lower.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


@router.get("/user/{uid}/{subfolder}/{filename}")
async def get_user_upload(
    uid: str,
    subfolder: str,
    filename: str,
    user: dict = Depends(get_current_user),
):
    """Legacy owner-only route for files written before the storage refactor."""
    current_uid = str(user.get("uid") or user.get("firebase_uid") or "")
    if not current_uid or current_uid != uid:
        raise HTTPException(status_code=403, detail="You do not have access to this file.")

    if subfolder not in {"avatars", "images"}:
        raise HTTPException(status_code=404, detail="File not found.")

    if Path(filename).name != filename:
        raise HTTPException(status_code=400, detail="Invalid filename.")

    upload_root = Path(UPLOAD_DIR).resolve()
    if not filename.startswith(f"{uid}_"):
        raise HTTPException(status_code=404, detail="File not found.")
    path = (upload_root / subfolder / filename).resolve()

    if path.parent not in {upload_root / subfolder, (upload_root / subfolder).resolve()}:
        raise HTTPException(status_code=400, detail="Invalid file path.")
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found.")

    return FileResponse(path)
