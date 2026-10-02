# backend/app/ai/utils/image_downloader.py

"""DEPRECATED: Compatibility shim for legacy image download utilities.
All new code must use the canonical ImageDownloadService from ../services/image_download_service.py.
This file exists only to maintain backward compatibility with existing code.
"""

import logging
from typing import Tuple, Any
from ..services.image_download_service import get_image_download_service

logger = logging.getLogger(__name__)

# Initialize the canonical service
_image_downloader = get_image_download_service()

def download_image(url: str, dest_path: str, max_retries: int = 3) -> Tuple[bool, str]:
    """DEPRECATED: Use canonical ImageDownloadService.download_to_file() instead.
    
    Legacy wrapper for backward compatibility. Delegates all download logic to the canonical service.
    """
    logger.warning("DEPRECATED: utils.image_downloader.download_image() is deprecated. Use ImageDownloadService directly.")
    success, status, _ = _image_downloader.download_to_file(url, dest_path, max_retries=max_retries)
    return success, status

def validate_image(file_path: str) -> Tuple[bool, str]:
    """DEPRECATED: Use canonical ImageDownloadService.validate_image_file() instead.
    
    Legacy wrapper for backward compatibility. Delegates all validation logic to the canonical service.
    """
    logger.warning("DEPRECATED: utils.image_downloader.validate_image() is deprecated. Use ImageDownloadService directly.")
    return _image_downloader.validate_image_file(file_path)

def compute_sha256(file_path: str) -> str:
    """DEPRECATED: Use canonical ImageDownloadService.compute_sha256() instead.
    
    Legacy wrapper for backward compatibility. Delegates all hash computation to the canonical service.
    """
    logger.warning("DEPRECATED: utils.image_downloader.compute_sha256() is deprecated. Use ImageDownloadService directly.")
    return _image_downloader.compute_sha256(file_path)

def extract_license(info: dict) -> Tuple[str, str, str, str]:
    """Extract license name, URL, author, and attribution requirements from a Wikimedia Commons file info dict.

    Returns a tuple ``(license_name, license_url, author, attribution_required)``. 
    If not available, returns empty strings or "unknown".
    """
    license_name = ""
    license_url = ""
    author = ""
    attribution_required = "false"
    
    if "license" in info:
        license_name = info["license"].get("name", "")
        license_url = info["license"].get("url", "")
        
    # Extract author information
    if "user" in info:
        author = info.get("user", {}).get("name", "")
    elif "artist" in info:
        author = info.get("artist", "")
        
    # Mark attribution required for CC BY, CC BY-SA
    if license_name.startswith(("CC BY", "CC BY-SA")):
        attribution_required = "true"
        
    return license_name, license_url, author, attribution_required

def compute_sha256(file_path: str) -> str:
    """Compute the SHA‑256 hash of the file at ``file_path`` and return the hex digest."""
    hash_sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hash_sha256.update(chunk)
    return hash_sha256.hexdigest()

def extract_license(info: dict) -> Tuple[str, str]:
    """Extract license name and URL from a Wikimedia Commons file info dict.

    Returns a tuple ``(license_name, license_url)``. If not available, returns empty strings.
    """
    license_name = ""
    license_url = ""
    if "license" in info:
        license_name = info["license"].get("name", "")
        license_url = info["license"].get("url", "")
    return license_name, license_url