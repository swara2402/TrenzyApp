"""Client IP resolution shared across HTTP and socket layers.

``X-Forwarded-For`` is only honored when ``TRUST_X_FORWARDED_FOR`` is enabled
(see ``config.py``); otherwise the direct peer address is used so clients
cannot spoof their origin by sending their own forwarded-for header.
"""

from .config import TRUST_X_FORWARDED_FOR


def get_client_ip(request) -> str:
    """Return the client IP for a Starlette/FastAPI Request."""
    if TRUST_X_FORWARDED_FOR:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return getattr(getattr(request, "client", None), "host", None) or "unknown"


def get_client_ip_from_environ(environ: dict) -> str:
    """Return the client IP from a WSGI/ASGI environ dict."""
    if TRUST_X_FORWARDED_FOR:
        forwarded = environ.get("HTTP_X_FORWARDED_FOR")
        if forwarded:
            return str(forwarded).split(",")[0].strip()
    return str(environ.get("REMOTE_ADDR") or "unknown")