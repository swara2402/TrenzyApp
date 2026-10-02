# backend/app/ai/config/image_acquisition.py

"""Configuration constants for the image acquisition pipeline.

Adjust these values as needed before running the acquisition script.
"""

# Number of images to fetch in total (target)
TARGET_IMAGE_COUNT = 500

# Wikimedia Commons categories to search (comma‑separated list)
CATEGORIES = [
    "Fashion",
    "Clothing",
    "Apparel",
    "Footwear",
    "Accessories",
]

# Directory to store downloaded images (relative to project root)
IMAGE_STORAGE_DIR = "backend/uploads/images"

# Maximum number of API requests per minute (to respect rate limits)
API_REQUESTS_PER_MINUTE = 30

# Optional Wikimedia Commons API user agent (required by WMF policy)
USER_AGENT = "TrenzyAI/1.0 (+https://github.com/yourorg/trenzy)"
