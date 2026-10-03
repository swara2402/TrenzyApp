"""Trenzy FastAPI application.

Creates and configures the FastAPI app instance with:

- **Lifespan**: Initializes database tables and Firebase Admin SDK on startup,
  disposes database connections on shutdown.
- **Exception handlers**: Structured JSON error responses for HTTP exceptions,
  validation errors, and unhandled exceptions.
- **Middleware**: Request logging (method, path, status, latency) and
  per-IP rate limiting (configurable window + max requests).
- **CORS**: Wide-open for development (``allow_origins=["*"]``).
- **Router registration**: 34 route modules covering products, auth, blends,
  trends, wardrobe, feed, and more.
- **Static files**: Serves uploaded files from ``UPLOAD_DIR`` at ``/uploads/``.

The ``api`` export wraps the FastAPI app with Socket.IO for real-time blend
communication. Use ``api`` (not ``app``) as the ASGI entry point.

CORS is handled at the ASGI middleware level (outermost layer) to ensure
ALL responses — including error responses from FastAPI exception handlers and
Socket.IO events — include the proper CORS headers. This is necessary because
the socketio.ASGIApp wrapper intercepts some requests before FastAPI's
CORSMiddleware can process them.
"""

import contextvars
import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Optional

import socketio
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.types import ASGIApp, Receive, Scope, Send

from .network import get_client_ip
from .rate_limit import rate_limiter

# Defer ML model loading to lifespan startup instead of import time
# This avoids the macOS libomp crash that occurs when unpickling LightGBM
# models after PyTorch has loaded. Models will be loaded once during app startup
# rather than at module import time.
def _preload_ml_models() -> None:
    ml_logger = logging.getLogger(__name__)
    ml_logger.info("ML model preloading deferred to app startup - will load models during initialization")

# Don't preload at import time to prevent libomp crash
# Models will be loaded in the lifespan startup function instead

# Don't preload at import time to prevent libomp crash
# Models will be loaded in the lifespan startup function instead

# Import core routes from routes/__init__.py that have proper _router naming
from .routes import (
    auth_router,
    decisions_router,
    feed_router,
    friends_router,
    notifications_router,
    products_router,
    suggestions_router,
    trends_router,
    users_router,
    wishlist_router,
    payments_router,
)

# Import all remaining route modules directly (they don't have _router exports yet)
from .routes import (
    blends,
    blend_features,
    brands,
    campaigns,
    cart,
    categories,
    events,
    follow,
    friend_suggestions,
    health,
    invitations,
    messages,
    moderation,
    blocks,
    persona,
    posts,
    product_images,
    product_variants,
    purchases,
    saves,
    search,
    uploads,
    wardrobe,
    # AI/ML route modules (use lazy-loading so PyTorch doesn't load at import time)
    ai,
    style_dna,
    recommendations,
)

# Don't call _preload_ml_models() at import time - models are loaded in lifespan startup
# This prevents the macOS libomp crash caused by conflicting PyTorch and LightGBM libomp copies

from .config import APP_ENV, UPLOAD_DIR, DEV_AUTH_BYPASS, IS_PRODUCTION
from .socket_server import sio

logger = logging.getLogger(__name__)

if DEV_AUTH_BYPASS:
    logger.critical(
        "DEV_AUTH_BYPASS is enabled — this MUST be disabled outside local "
        "development (current APP_ENV=%s).",
        APP_ENV,
    )

if IS_PRODUCTION:
    logger.info("Running in production mode (APP_ENV=%s).", APP_ENV)
else:
    logger.warning(
        "Running in development mode (APP_ENV=%s). Ensure CORS_ALLOWED_ORIGINS "
        "and SOCKET_ALLOWED_ORIGINS are set for real deployments.",
        APP_ENV,
    )

# Sentry Error Tracking (Optional)
SENTRY_DSN = os.getenv("SENTRY_DSN", "").strip()
if SENTRY_DSN:
    try:
        import sentry_sdk  # type: ignore
        from sentry_sdk.integrations.fastapi import FastApiIntegration  # type: ignore
        sentry_sdk.init(
            dsn=SENTRY_DSN,
            environment=APP_ENV,
            traces_sample_rate=0.1 if IS_PRODUCTION else 1.0,
            integrations=[FastApiIntegration()],
        )
        logger.info("Sentry error tracking initialized (environment=%s)", APP_ENV)
    except ImportError:
        logger.warning("SENTRY_DSN configured but sentry-sdk package not installed.")
    except Exception as e:
        logger.error("Failed to initialize Sentry: %s", e)

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
# Default LOG_FORMAT to 'json' in production for structured logging compliance
default_log_format = "json" if IS_PRODUCTION else "text"
LOG_FORMAT = os.getenv("LOG_FORMAT", default_log_format)

_DEFAULT_TEXT_FORMAT = "%(asctime)s | %(levelname)-7s | %(name)s | %(message)s"

log_format_mode = LOG_FORMAT.lower()

if log_format_mode == "json":
    import json

    class JSONFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            return json.dumps({
                "timestamp": self.formatTime(record, self.datefmt),
                "level": record.levelname,
                "logger": record.name,
                "message": record.getMessage(),
                "module": record.module,
                "line": record.lineno,
            })

    logging.basicConfig(level=LOG_LEVEL, handlers=[
        logging.StreamHandler(),
    ])
    for handler in logging.getLogger().handlers:
        handler.setFormatter(JSONFormatter())
elif log_format_mode == "text":
    logging.basicConfig(
        level=LOG_LEVEL,
        format=_DEFAULT_TEXT_FORMAT,
        datefmt="%Y-%m-%d %H:%M:%S",
    )
else:
    logging.basicConfig(
        level=LOG_LEVEL,
        format=LOG_FORMAT,
        datefmt="%Y-%m-%d %H:%M:%S",
    )

logger = logging.getLogger(__name__)

# Rate limiting is handled by app/rate_limit.py.
# Supports in-memory (single-worker) and Redis (multi-worker) backends.
# Configure via REDIS_URL, RATE_LIMIT_WINDOW, RATE_LIMIT_MAX_REQUESTS env vars.


@asynccontextmanager
async def lifespan(app_context: FastAPI):
    """Startup: initialize all app components.
    Shutdown: gracefully dispose all resources."""
    from .initialization import initialize_app, shutdown_app
    
    # Initialize all components (logging, DB, Firebase, Redis, etc.)
    await initialize_app()
    
    yield
    
    # Clean up all resources
    await shutdown_app()


app = FastAPI(title="Trenzy API", lifespan=lifespan)


# ---------------------------------------------------------------------------
# Global exception handlers — structured JSON error responses
# ---------------------------------------------------------------------------

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """Convert HTTPException into a structured JSON error body."""
    # Map common status codes to machine-readable error codes
    _code_map = {
        400: "bad_request",
        401: "unauthorized",
        403: "forbidden",
        404: "not_found",
        405: "method_not_allowed",
        409: "conflict",
        429: "rate_limited",
        500: "internal_error",
        502: "bad_gateway",
        503: "service_unavailable",
    }
    error_code = _code_map.get(exc.status_code, "error")
    detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "error_code": error_code,
            "message": detail,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Convert Pydantic/validation errors into a structured JSON error body."""
    errors = []
    for err in exc.errors():
        loc = " -> ".join(str(part) for part in err.get("loc", []))
        errors.append({
            "field": loc,
            "message": err.get("msg", "Invalid value"),
            "type": err.get("type", "value_error"),
        })
    return JSONResponse(
        status_code=422,
        content={
            "status": "error",
            "error_code": "validation_error",
            "message": "Request validation failed",
            "details": errors,
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Catch-all: log the full traceback, return a safe structured response."""
    logger.error(
        "Unhandled exception %s %s: %s",
        request.method,
        request.url.path,
        exc,
        exc_info=True,
    )
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "error_code": "internal_error",
            "message": "An unexpected error occurred. Please try again later.",
        },
    )


# ============================================================================
# Request ID / Correlation ID Context
# ============================================================================
# Provides request tracing across REST endpoints and Socket.IO events.

request_id_var: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar(
    'request_id', default=None
)


def get_request_id() -> str:
    """Get or generate a request ID for correlation/tracing."""
    req_id = request_id_var.get()
    if req_id is None:
        req_id = f"req-{uuid.uuid4().hex[:12]}"
        request_id_var.set(req_id)
    return req_id


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    """Add request ID to context and response headers for tracing/correlation."""
    # Check if client provided a request ID (X-Request-ID or X-Correlation-ID header)
    req_id = request.headers.get("X-Request-ID") or request.headers.get("X-Correlation-ID")
    if not req_id:
        req_id = f"req-{uuid.uuid4().hex[:12]}"
    
    # Store in context for use in routes, logging, Socket.IO, etc.
    token = request_id_var.set(req_id)
    
    try:
        response = await call_next(request)
        # Attach request ID to response headers for client correlation
        response.headers["X-Request-ID"] = req_id
        return response
    finally:
        request_id_var.reset(token)


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """Attach production security headers to every response."""
    response = await call_next(request)
    # Prevent MIME-type sniffing
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    # Clickjacking protection
    response.headers.setdefault("X-Frame-Options", "DENY")
    # Basic XSS filter (legacy but still useful)
    response.headers.setdefault("X-XSS-Protection", "1; mode=block")
    # Referrer policy
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    # Permissions policy (disable powerful features by default)
    response.headers.setdefault(
        "Permissions-Policy",
        "camera=(), microphone=(), geolocation=(), payment=()",
    )
    # HSTS only when we are clearly on HTTPS / production
    from .config import IS_PRODUCTION
    if IS_PRODUCTION:
        response.headers.setdefault(
            "Strict-Transport-Security",
            "max-age=31536000; includeSubDomains; preload",
        )
    return response


@app.middleware("http")
async def log_requests(request: Request, call_next):
    req_id = get_request_id()
    start = time.time()
    response = await call_next(request)
    elapsed = time.time() - start
    logger.info(
        "%s %s -> %d (%.0fms)",
        request.method,
        request.url.path,
        response.status_code,
        elapsed * 1000,
        extra={"request_id": req_id},
    )
    return response


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if request.url.path.startswith("/api/health"):
        return await call_next(request)

    # Only trust x-forwarded-for when behind a known reverse proxy.
    client_ip = get_client_ip(request)

    if not rate_limiter.is_allowed(client_ip):
        logger.warning("Rate limit exceeded for IP %s on %s", client_ip, request.url.path)
        error_response = rate_limiter.error_response()
        return JSONResponse(
            status_code=429,
            content=error_response,
            headers={"Retry-After": str(error_response.get("retry_after", 60))}
        )

    return await call_next(request)


_MAX_REQUEST_BYTES = int(os.getenv("MAX_REQUEST_BODY_BYTES", "1_000_000"))


@app.middleware("http")
async def limit_request_body(request: Request, call_next):
    """Reject requests whose body exceeds MAX_REQUEST_BODY_BYTES early.

    Prevents unbounded body buffering and cheap DoS via huge JSON payloads.
    Uploads are deliberately excluded from the cap — they are streamed to disk
    with their own size validation in the uploads route.
    """
    if (
        request.method in {"POST", "PUT", "PATCH", "DELETE"}
        and not request.url.path.startswith("/api/uploads")
    ):
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > _MAX_REQUEST_BYTES:
                    return JSONResponse(
                        status_code=413,
                        content={
                            "detail": f"Request body exceeds {_MAX_REQUEST_BYTES} bytes",
                            "code": "PAYLOAD_TOO_LARGE",
                        },
                    )
            except ValueError:
                pass
        else:
            # No content-length (chunked encoding): enforce the cap while
            # buffering, then hand the buffered body back to the app so the
            # request remains readable downstream.
            chunks: list[bytes] = []
            total = 0
            async for chunk in request.stream():
                total += len(chunk)
                if total > _MAX_REQUEST_BYTES:
                    return JSONResponse(
                        status_code=413,
                        content={
                            "detail": f"Request body exceeds {_MAX_REQUEST_BYTES} bytes",
                            "code": "PAYLOAD_TOO_LARGE",
                        },
                    )
                chunks.append(chunk)
            buffered = b"".join(chunks)

            buffered_sent = False

            async def receive():
                nonlocal buffered_sent
                if not buffered_sent:
                    buffered_sent = True
                    return {"type": "http.request", "body": buffered, "more_body": False}
                return {"type": "http.request", "body": b"", "more_body": False}

            request._receive = receive
    return await call_next(request)


_cors_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
if _cors_origins_env.strip():
    _cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()]
    # In production, explicitly reject any wildcard
    if IS_PRODUCTION and any("*" in origin for origin in _cors_origins):
        raise RuntimeError(
            "Refusing to start: CORS_ALLOWED_ORIGINS contains wildcard '*' in production. "
            "Set CORS_ALLOWED_ORIGINS to specific allowed origins only (comma-separated)."
        )
else:
    if IS_PRODUCTION:
        raise RuntimeError(
            "Refusing to start: CORS_ALLOWED_ORIGINS is not set in production. "
            "Set CORS_ALLOWED_ORIGINS to a comma-separated list of allowed origins."
        )
    logger.warning(
        "CORS_ALLOWED_ORIGINS not set — wide-open CORS for development. "
        "Set CORS_ALLOWED_ORIGINS in .env for production to restrict origins."
    )
    # In development, allow all origins
    _cors_origins = ["*"]

# Also fail if production explicitly uses wildcard
if IS_PRODUCTION and "*" in _cors_origins:
    raise RuntimeError(
        "Refusing to start: CORS_ALLOWED_ORIGINS contains '*' in production. "
        "Set CORS_ALLOWED_ORIGINS to specific allowed origins."
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Core routes from routes/__init__.py with proper _router suffixes
app.include_router(auth_router)
app.include_router(decisions_router)
app.include_router(feed_router)
app.include_router(friends_router)
app.include_router(notifications_router)
app.include_router(products_router)
app.include_router(suggestions_router)
app.include_router(trends_router)
app.include_router(users_router)
app.include_router(wishlist_router)
app.include_router(payments_router)
app.include_router(ai.router)
app.include_router(campaigns.router)
app.include_router(moderation.router)
app.include_router(blocks.router)
app.include_router(invitations.router)
app.include_router(search.router)
app.include_router(messages.router)
app.include_router(uploads.router)
app.include_router(health.router)
app.include_router(recommendations.router)
app.include_router(recommendations.recommend_router)
app.include_router(wardrobe.router)
app.include_router(persona.router)
app.include_router(posts.router)
# Serve uploaded files
os.makedirs(UPLOAD_DIR, exist_ok=True)
# Only catalog assets are public. User uploads (avatars/wardrobe/post images)
# are served through authenticated routes in routes/uploads.py.
_PRODUCT_IMAGE_DIR = os.path.join(UPLOAD_DIR, "product-images", "images")
if os.path.isdir(_PRODUCT_IMAGE_DIR):
    app.mount("/product-images", StaticFiles(directory=_PRODUCT_IMAGE_DIR), name="product-images")

app.include_router(blends.router)
app.include_router(blend_features.router)
app.include_router(brands.router)
app.include_router(cart.router)
app.include_router(categories.router)
app.include_router(follow.router)
app.include_router(friend_suggestions.router)
app.include_router(product_images.router)
app.include_router(product_variants.router)
app.include_router(purchases.router)
app.include_router(saves.router)
app.include_router(style_dna.router)
app.include_router(events.router)

# Export request_id functions for use in Socket.IO and other modules
__all__ = ["app", "api", "get_request_id", "request_id_var"]

# ---------------------------------------------------------------------------
# ASGI CORS Middleware — wraps the outermost layer so ALL responses,
# including FastAPI errors and Socket.IO events, get CORS headers.
# ---------------------------------------------------------------------------

_CORS_ALLOWED_ORIGINS_LIST = _cors_origins  # reuse the parsed origins


def _is_origin_allowed(origin: str, allowed: list[str]) -> bool:
    """Check if an origin is in the allowed list. Supports wildcard '*'."""
    if "*" in allowed:
        return True
    return origin in allowed


class CORSASGIMiddleware:
    """Outermost ASGI middleware that attaches CORS headers to every response.

    This is necessary because:

    1. The ``socketio.ASGIApp`` intercepts requests before FastAPI's
       ``CORSMiddleware`` can process them.
    2. Error responses from FastAPI exception handlers may not flow through
       the FastAPI middleware stack correctly when wrapped by Socket.IO.
    3. OPTIONS preflight requests need to be handled at the ASGI level.

    For development, ``allow_origins`` defaults to ``["*"]``. In production,
    set ``CORS_ALLOWED_ORIGINS`` to a comma-separated list of allowed origins.
    """

    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_cors(message):
            if message["type"] == "http.response.start":
                orig_headers = message.get("headers", [])
                headers_dict = {k: v for k, v in orig_headers}
                origin = None
                for k, v in scope.get("headers", []):
                    if k == b"origin":
                        origin = v.decode("utf-8", errors="ignore")
                        break

                if origin and b"access-control-allow-origin" not in headers_dict:
                    if _is_origin_allowed(origin, _CORS_ALLOWED_ORIGINS_LIST):
                        orig_headers = list(orig_headers)
                        orig_headers.append((b"access-control-allow-origin", origin.encode()))
                        orig_headers.append((b"access-control-allow-methods", b"GET, POST, PUT, PATCH, DELETE, OPTIONS"))
                        orig_headers.append((b"access-control-allow-headers", b"*"))
                        orig_headers.append((b"access-control-allow-credentials", b"false"))
                        orig_headers.append((b"access-control-max-age", b"86400"))
                        message["headers"] = orig_headers

            await send(message)

        # Handle OPTIONS preflight requests at the ASGI level
        if scope["method"] == "OPTIONS":
            origin = None
            for k, v in scope.get("headers", []):
                if k == b"origin":
                    origin = v.decode("utf-8", errors="ignore")
                    break

            if origin and _is_origin_allowed(origin, _CORS_ALLOWED_ORIGINS_LIST):
                allow_origin = origin
            elif "*" in _CORS_ALLOWED_ORIGINS_LIST:
                allow_origin = "*"
            else:
                allow_origin = _CORS_ALLOWED_ORIGINS_LIST[0] if _CORS_ALLOWED_ORIGINS_LIST else ""

            headers = [
                (b"access-control-allow-origin", allow_origin.encode()),
                (b"access-control-allow-methods", b"GET, POST, PUT, PATCH, DELETE, OPTIONS"),
                (b"access-control-allow-headers", b"*"),
                (b"access-control-allow-credentials", b"false"),
                (b"access-control-max-age", b"86400"),
            ]
            response_scope = {
                "type": "http.response.start",
                "status": 204,
                "headers": headers,
            }
            await send(response_scope)
            await send({"type": "http.response.body", "body": b""})
            return

        await self.app(scope, receive, send_with_cors)


# Build the stack: socketio.ASGIApp(sio) wraps the CORS-wrapped FastAPI `app`.
#
# IMPORTANT: The generic CORS middleware must wrap ONLY the inner FastAPI app,
# NOT the socketio.ASGIApp. python-socketio emits its own CORS preflight +
# response headers for /socket.io based on its allowed-origins allowlist
# (including a matching `Access-Control-Allow-Credentials: true`). Wrapping
# the ASGIApp too produced DUPLICATE headers on every socket.io response —
# engineio's `Access-Control-Allow-Credentials: true` followed by the
# middleware's `...: false`. Browsers honour the LAST duplicate, so any
# socket.io XHR with credentials was rejected as a CORS failure ("xhr poll
# error"), which silently bricked chat/swipes/presence on the web client.
_cors_app = CORSASGIMiddleware(app)
_socket_app = socketio.ASGIApp(sio, other_asgi_app=_cors_app)
api = _socket_app