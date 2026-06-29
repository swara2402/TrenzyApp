import os
from pathlib import Path
from dotenv import load_dotenv

# Load env from the backend/ directory (config-file-relative, not CWD-relative).
_backend_dir = Path(__file__).resolve().parent.parent
_dotenv_path = _backend_dir / ".env"
load_dotenv(_dotenv_path)


POSTGRES_DSN = os.getenv("POSTGRES_DSN")
if not POSTGRES_DSN:
    raise RuntimeError(
        "POSTGRES_DSN environment variable is required. "
        "Example: postgresql+psycopg://postgres:STRONG_PASSWORD@localhost:5432/trenzy"
    )

# Firebase Admin
# Provide credentials via one of:
# - FIREBASE_SERVICE_ACCOUNT_JSON (raw json string)
# - FIREBASE_SERVICE_ACCOUNT_FILE (path to json file)
FIREBASE_SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
FIREBASE_SERVICE_ACCOUNT_FILE = os.getenv("FIREBASE_SERVICE_ACCOUNT_FILE")

# Firebase Web Auth (Identity Toolkit) for email/password login/signup.
# Flutter expects email+password auth endpoints from this backend.
# REQUIRED:
# - FIREBASE_API_KEY
FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY")

# Identity Toolkit base URL
FIREBASE_AUTH_BASE_URL = os.getenv(
    "FIREBASE_AUTH_BASE_URL",
    "https://identitytoolkit.googleapis.com/v1",
)





