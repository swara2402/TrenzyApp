"""Image hashing utilities for deduplication and provenance tracking."""

import hashlib
import io
from typing import Tuple, Optional
from PIL import Image
import imagehash


def compute_sha256(data: bytes) -> str:
    """Compute hex SHA-256 hash of bytes."""
    return hashlib.sha256(data).hexdigest()


def compute_phash(image: Image.Image) -> str:
    """Compute perceptual hash (pHash) of a PIL Image."""
    return str(imagehash.phash(image))


def compute_image_hashes(image_bytes: bytes) -> Tuple[str, str, int, int]:
    """Compute SHA-256, pHash, width, height from raw image bytes.

    Returns:
        Tuple of (sha256_hex, phash_str, width, height)
    """
    sha256 = compute_sha256(image_bytes)
    with Image.open(io.BytesIO(image_bytes)) as img:
        width, height = img.size
        # Ensure RGB mode for consistent pHash calculation
        rgb_img = img.convert("RGB")
        phash = compute_phash(rgb_img)
    return sha256, phash, width, height
