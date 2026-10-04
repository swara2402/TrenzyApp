"""Canonical ImageDownloadService - the ONLY image downloader in Trenzy.

This service implements all required image download functionality:
- Wikimedia-compliant User-Agent
- 429 rate limiting handling with Retry-After support
- Exponential backoff with jitter
- Bounded retries from ml_config
- Local file caching
- 6-state image validation: VALID, TEMPORARY_FAILURE, PERMANENT_FAILURE, INVALID_IMAGE, CACHE_HIT
- SHA256 checksum computation
- Image validation (decoding, minimum dimensions, file size)
- PIL Image in-memory download for embedding generation
- File download to local storage for image acquisition

All other image download code must be migrated to use this service. No duplicate implementations allowed.
"""

import os
import time
import random
import hashlib
import logging
from typing import Tuple, Optional, Union
from PIL import Image
from io import BytesIO
import requests

from ..ml_config import IMAGE_DOWNLOAD_MAX_RETRIES, IMAGE_DOWNLOAD_BACKOFF_BASE, MIN_IMAGE_WIDTH, MIN_IMAGE_HEIGHT

# Canonical User-Agent - compliant with Wikimedia Commons requirements
TRENZY_USER_AGENT = "Trenzy/1.0 (https://github.com/trenzy; contact@trenzy.ai) Python/requests"

logger = logging.getLogger(__name__)

class ImageDownloadService:
    """Singleton canonical image download service."""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        # Public attributes for use across the codebase
        self.user_agent = TRENZY_USER_AGENT
        logger.info("Canonical ImageDownloadService initialized")
    
    def _handle_rate_limit(self, retry_after: int, attempt: int) -> None:
        """Public method to handle rate limiting (429) with correct backoff logic.
        
        Args:
            retry_after: Retry-After header value from the server (0 if not present)
            attempt: Current attempt number (0-indexed)
        """
        if retry_after:
            logger.warning(f"429 received, Retry-After: {retry_after}s")
            time.sleep(retry_after)
        else:
            backoff = IMAGE_DOWNLOAD_BACKOFF_BASE * (2 ** attempt) + random.uniform(0, 2)
            logger.warning(f"Rate limited (429), retry {attempt + 1}/{IMAGE_DOWNLOAD_MAX_RETRIES} after {backoff:.1f}s")
            time.sleep(backoff)
    
    @staticmethod
    def get_instance() -> 'ImageDownloadService':
        """Get the singleton instance of ImageDownloadService."""
        if ImageDownloadService._instance is None:
            ImageDownloadService()
        return ImageDownloadService._instance
    
    def download_to_memory(self, image_url: str) -> Tuple[bool, str, Optional[Image.Image]]:
        """Download an image to memory as a PIL Image (for embedding generation).
        
        Args:
            image_url: URL of the image to download
            
        Returns:
            Tuple of (success: bool, status: str, image: Optional[Image.Image])
            Status codes: VALID, TEMPORARY_FAILURE, PERMANENT_FAILURE, INVALID_IMAGE
        """
        attempt = 0
        while attempt <= IMAGE_DOWNLOAD_MAX_RETRIES:
            try:
                response = requests.get(
                    image_url,
                    timeout=(10, 30),
                    headers={"User-Agent": TRENZY_USER_AGENT}
                )
                
                # Handle rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", 0))
                    self._handle_rate_limit(retry_after, attempt)
                    attempt += 1
                    continue
                
                response.raise_for_status()
                
                # Create PIL image
                img = Image.open(BytesIO(response.content)).convert("RGB")
                
                # Validate image dimensions
                width, height = img.size
                if width < MIN_IMAGE_WIDTH or height < MIN_IMAGE_HEIGHT:
                    logger.error(f"Image too small: {width}x{height} < {MIN_IMAGE_WIDTH}x{MIN_IMAGE_HEIGHT} for {image_url}")
                    return False, "INVALID_IMAGE", None
                
                return True, "VALID", img
                
            except requests.HTTPError as http_err:
                status = http_err.response.status_code if http_err.response else None
                if status in [429, 500, 502, 503, 504]:
                    if attempt < IMAGE_DOWNLOAD_MAX_RETRIES:
                        backoff = IMAGE_DOWNLOAD_BACKOFF_BASE * (2 ** attempt) + random.uniform(0, 2)
                        logger.warning(f"Temporary error {status}, retry {attempt + 1}/{IMAGE_DOWNLOAD_MAX_RETRIES} after {backoff:.1f}s for {image_url}")
                        time.sleep(backoff)
                        attempt += 1
                        continue
                    else:
                        return False, "TEMPORARY_FAILURE", None
                else:
                    logger.error(f"Permanent HTTP error {status} for {image_url}: {http_err}")
                    return False, "PERMANENT_FAILURE", None
                    
            except Exception as e:
                if attempt < IMAGE_DOWNLOAD_MAX_RETRIES:
                    backoff = IMAGE_DOWNLOAD_BACKOFF_BASE * (2 ** attempt) + random.uniform(0, 2)
                    logger.warning(f"Error downloading {image_url}: {e}; retry {attempt + 1}/{IMAGE_DOWNLOAD_MAX_RETRIES} after {backoff:.1f}s")
                    time.sleep(backoff)
                    attempt += 1
                    continue
                else:
                    return False, "TEMPORARY_FAILURE", None
        
        return False, "PERMANENT_FAILURE", None
    
    def download_to_file(self, image_url: str, dest_path: str, max_retries: int = None) -> Tuple[bool, str, None]:
        """Download an image to a local file (for image acquisition/storage).
        
        Args:
            image_url: URL of the image to download
            dest_path: Local file path to save the image
            max_retries: Override the default max retries (uses IMAGE_DOWNLOAD_MAX_RETRIES from ml_config if None)
            
        Returns:
            Tuple of (success: bool, status: str, None) to maintain consistent return signature with download_to_memory
            Status codes: VALID, CACHE_HIT, TEMPORARY_FAILURE, PERMANENT_FAILURE, INVALID_IMAGE
        """
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        max_attempts = max_retries if max_retries is not None else IMAGE_DOWNLOAD_MAX_RETRIES
        
        # Check cache - return CACHE_HIT if already valid
        if os.path.exists(dest_path):
            valid, _ = self.validate_image_file(dest_path)
            if valid:
                logger.debug(f"Cache hit for {dest_path}")
                return True, "CACHE_HIT", None
        
        attempt = 0
        while attempt <= max_attempts:
            try:
                response = requests.get(
                    image_url,
                    stream=True,
                    timeout=(10, 30),
                    headers={"User-Agent": TRENZY_USER_AGENT}
                )
                
                # Handle rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", 0))
                    self._handle_rate_limit(retry_after, attempt)
                    attempt += 1
                    continue
                
                response.raise_for_status()
                
                # Download to temporary file first
                temp_path = f"{dest_path}.tmp"
                with open(temp_path, "wb") as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                
                # Validate the downloaded image
                valid, validation_status = self.validate_image_file(temp_path)
                if not valid:
                    os.unlink(temp_path)
                    return False, validation_status, None
                
                # Move to final destination
                os.rename(temp_path, dest_path)
                return True, "VALID", None
                
            except requests.HTTPError as http_err:
                status = http_err.response.status_code if http_err.response else None
                if status in [429, 500, 502, 503, 504]:
                    if attempt < max_attempts:
                        backoff = IMAGE_DOWNLOAD_BACKOFF_BASE * (2 ** attempt) + random.uniform(0, 2)
                        logger.warning(f"Temporary error {status}, retry {attempt + 1}/{max_attempts} after {backoff:.1f}s for {image_url}")
                        time.sleep(backoff)
                        attempt += 1
                        continue
                    else:
                        return False, "TEMPORARY_FAILURE", None
                else:
                    logger.error(f"Permanent HTTP error {status} for {image_url}: {http_err}")
                    return False, "PERMANENT_FAILURE", None
                    
            except Exception as e:
                if attempt < max_attempts:
                    backoff = IMAGE_DOWNLOAD_BACKOFF_BASE * (2 ** attempt) + random.uniform(0, 2)
                    logger.warning(f"Error downloading {image_url}: {e}; retry {attempt + 1}/{max_attempts} after {backoff:.1f}s")
                    time.sleep(backoff)
                    attempt += 1
                    continue
                else:
                    return False, "TEMPORARY_FAILURE", None
            
        return False, "PERMANENT_FAILURE", None
    
    def validate_image_file(self, file_path: str) -> Tuple[bool, str]:
        """Validate a local image file for corruption, minimum size, and dimensions.
        
        Args:
            file_path: Path to image file
            
        Returns:
            Tuple of (is_valid: bool, status: str)
        """
        try:
            if not os.path.exists(file_path):
                return False, "INVALID_IMAGE"
                
            file_size = os.path.getsize(file_path)
            if file_size < 1024:  # Minimum 1KB
                return False, "INVALID_IMAGE"
                
            # Verify it can be decoded and has reasonable dimensions
            with Image.open(file_path) as img:
                width, height = img.size
                if width < MIN_IMAGE_WIDTH or height < MIN_IMAGE_HEIGHT:
                    logger.error(f"Image dimensions {width}x{height} below minimum {MIN_IMAGE_WIDTH}x{MIN_IMAGE_HEIGHT}")
                    return False, "INVALID_IMAGE"
                    
                # Verify image can be converted to RGB (basic corruption check)
                img.convert("RGB")
                
            return True, "VALID"
            
        except Exception as e:
            logger.warning(f"Image validation failed for {file_path}: {e}")
            return False, "INVALID_IMAGE"
    
    def compute_sha256(self, file_path: str) -> str:
        """Compute SHA-256 hash of a file."""
        hash_sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()

# Convenience function to get the service instance
def get_image_download_service() -> ImageDownloadService:
    """Get the canonical ImageDownloadService singleton instance."""
    return ImageDownloadService.get_instance()