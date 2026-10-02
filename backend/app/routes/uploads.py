"""File upload endpoint for user profile images and post attachments.

Accepts multipart file uploads, validates file extension and magic bytes,
generates a UUID filename, saves securely to the configured upload directory,
and returns the public URL.
"""
from __future__ import annotations

import logging
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from ..config import UPLOAD_BASE_URL, UPLOAD_DIR
from ..storage import save_bytes, backend_name, StorageError
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


async def _validate_and_save_upload(
    file: UploadFile, uid: str, subfolder: str
) -> str:
    """Validate upload headers, size, magic bytes, and save with UUID filename.
    
    Returns an authenticated URL string.
    """
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
            detected_ext, ext
        )
        raise HTTPException(status_code=400, detail=f"File content does not match extension {ext}")

    upload_root = Path(UPLOAD_DIR).resolve()
    upload_path = (upload_root / subfolder).resolve()
    upload_path.mkdir(parents=True, exist_ok=True)

    safe_uid = "".join(c for c in uid if c.isalnum() or c in "-_")[:64]
    if not safe_uid:
        safe_uid = "user"

    filename = f"{safe_uid}_{uuid.uuid4().hex}{ext}"
    filepath = (upload_path / filename).resolve()

    # Prevent path traversal across platforms
    if filepath.parent != upload_path:
        logger.error("Upload path traversal detected for uid %s — refusing write", uid)
        raise HTTPException(status_code=400, detail="Invalid upload destination")

    filepath.write_bytes(contents)
    return f"/api/uploads/user/{safe_uid}/{subfolder}/{filename}"


@router.post("/avatar")
async def upload_avatar(
    file: UploadFile,
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, str]:
    """Upload user avatar and update profile."""
    uid = user.get("uid") or user.get("firebase_uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    avatar_url = await _validate_and_save_upload(file, str(uid), "avatars")

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
    """Upload a general image (wardrobe item, post attachment, etc.)."""
    uid = user.get("uid") or user.get("firebase_uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    image_url = await _validate_and_save_upload(file, str(uid), "images")
    return {"image_url": image_url, "imageUrl": image_url}

@router.get("/storage-info")
async def storage_info(user: dict = Depends(get_current_user)):
    """Return active storage backend (local|s3) for ops visibility."""
    return {"backend": backend_name()}



@router.get("/user/{uid}/{subfolder}/{filename}")
async def get_user_upload(
    uid: str,
    subfolder: str,
    filename: str,
    user: dict = Depends(get_current_user),
):
    """Serve a user's private upload only to that same authenticated user."""
    current_uid = str(user.get("uid") or user.get("firebase_uid") or "")
    if not current_uid or current_uid != uid:
        raise HTTPException(status_code=403, detail="You do not have access to this file.")

    if subfolder not in {"avatars", "images"}:
        raise HTTPException(status_code=404, detail="File not found.")

    if Path(filename).name != filename:
        raise HTTPException(status_code=400, detail="Invalid filename.")

    upload_root = Path(UPLOAD_DIR).resolve()
    path = (upload_root / subfolder / f"{uid}_{filename}").resolve()
    # Filenames generated by this service are uid-prefixed. Also support legacy
    # files whose stored name already begins with the uid.
    if not path.exists():
        path = (upload_root / subfolder / filename).resolve()

    if path.parent not in {upload_root / subfolder, (upload_root / subfolder).resolve()}:
        raise HTTPException(status_code=400, detail="Invalid file path.")
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found.")

    return FileResponse(path)
