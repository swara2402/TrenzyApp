import os
import logging
import socketio
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .db import engine
from .models import Base
from .socket_server import sio
from .firebase_auth import init_firebase_admin, _firebase_initialized

from .routes import (
    trends,
    auth,
    suggestions,
    decisions,
    products,
    wishlist,
    groups,
    users,
    invitations,
    messages,
    friends,
)

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Create FastAPI app
app = FastAPI(title="Trenzy API")

# ------------------------
# CORS (configurable via env)
# ------------------------
_allowed_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
if _allowed_origins_env.strip() and _allowed_origins_env.strip() != "*":
    _allowed_origins = [o.strip() for o in _allowed_origins_env.split(",") if o.strip()]
elif _allowed_origins_env.strip() == "*":
    # Explicit wildcard - use '*' to allow all origins
    # Note: This won't work with allow_credentials=True
    # FastAPI CORSMiddleware handles this correctly
    _allowed_origins = ["*"]
else:
    # Dev default — localhost only (wildcard + credentials is rejected by browsers)
    _allowed_origins = [
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://localhost:5000",
        "http://127.0.0.1:5000",
        "http://localhost:61310",
        "http://127.0.0.1:61310",
    ]

# Enhanced CORS middleware with debug logging
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # Ensure proper header exposure
)

def on_startup():
    Base.metadata.create_all(bind=engine)

    # Initialize Firebase Admin — fail fast if missing.
    # In production this MUST succeed; the auth module no longer has a
    # signature-bypass fallback, so we cannot boot without Firebase Admin.
    init_firebase_admin()
    if not _firebase_initialized:
        raise RuntimeError(
            "Firebase Admin failed to initialize. "
            "Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE. "
            "Refusing to start — auth would be wide open."
        )
    logger.info("Firebase Admin initialized. Auth is secured.")


# ------------------------
# Routers
# ------------------------
app.include_router(auth.router)
app.include_router(suggestions.router)
app.include_router(decisions.router)
app.include_router(products.router)
app.include_router(wishlist.router)
app.include_router(groups.router)
app.include_router(users.router)
app.include_router(invitations.router)
app.include_router(messages.router)
app.include_router(friends.router)
app.include_router(trends.router)

# Keep a reference to the FastAPI app
api = app

# ------------------------
# Socket.IO wrapper
# ------------------------
# IMPORTANT: uvicorn in Docker runs `uvicorn app.main:api ...`.
# That means we must expose an ASGI callable at `api` that includes Socket.IO.
api = socketio.ASGIApp(
    sio,
    other_asgi_app=app,
)
