"""Rate limiting with Redis backend and production safety guarantees.

Provides rate limiting across multiple scenarios:
- **Per-IP rate limiting**: Limit requests per IP address (general HTTP)
- **Per-socket rate limiting**: Limit socket events per socket ID (Socket.IO)
- **Per-user rate limiting**: Limit requests per user ID (authentication/abuse prevention)
- **Connection rate limiting**: Limit new connections per IP (DoS protection)

Configuration via environment variables:
- REDIS_URL: Redis connection string (e.g., redis://localhost:6379/0).
             **REQUIRED in production** — single-process rate limiting is unsafe.
- RATE_LIMIT_WINDOW: Sliding window in seconds (default: 60).
- RATE_LIMIT_MAX_REQUESTS: Max requests per window per key (default: 60).
- RATE_LIMIT_CONNECTION_MAX: Max connections per IP per minute (default: 20).

Production Safety:
- In production (APP_ENV=production), Redis failures FAIL CLOSED on rate limiting checks.
- In development/local environments, controlled in-memory fallback is used.
"""

from __future__ import annotations

import logging
import os
import time
from collections import defaultdict

logger = logging.getLogger(__name__)

REDIS_URL = os.getenv("REDIS_URL", "")
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))
RATE_LIMIT_MAX_REQUESTS = int(os.getenv("RATE_LIMIT_MAX_REQUESTS", "60"))
RATE_LIMIT_CONNECTION_MAX = int(os.getenv("RATE_LIMIT_CONNECTION_MAX", "20"))
_MAX_IPS = 50_000
_CLEANUP_INTERVAL = 60


def _get_is_production() -> bool:
    app_env = os.getenv("APP_ENV", "production").strip().lower()
    return app_env not in {"development", "dev", "local", "test"}


IS_PRODUCTION = _get_is_production()


class InMemoryRateLimiter:
    """Sliding-window rate limiter backed by a dict. Single-worker only."""

    def __init__(self) -> None:
        self._store: dict[str, list[float]] = defaultdict(list)
        self._connection_store: dict[str, list[float]] = defaultdict(list)
        self._last_cleanup: float = 0.0

    def _cleanup(self, now: float) -> None:
        if now - self._last_cleanup < _CLEANUP_INTERVAL:
            return
        self._last_cleanup = now
        window_start = now - RATE_LIMIT_WINDOW
        stale = [ip for ip, ts in self._store.items()
                 if not ts or ts[-1] <= window_start]
        for ip in stale:
            del self._store[ip]
        if len(self._store) > _MAX_IPS:
            sorted_ips = sorted(
                self._store,
                key=lambda ip: self._store[ip][-1] if self._store[ip] else 0,
            )
            for ip in sorted_ips[: len(sorted_ips) // 2]:
                del self._store[ip]

    def is_allowed(self, key: str) -> bool:
        now = time.time()
        self._cleanup(now)
        window_start = now - RATE_LIMIT_WINDOW
        timestamps = self._store[key]
        timestamps[:] = [t for t in timestamps if t > window_start]
        if len(timestamps) >= RATE_LIMIT_MAX_REQUESTS:
            return False
        timestamps.append(now)
        return True

    def is_allowed_connection(self, key: str) -> bool:
        """Check connection-level rate limit (per minute, not per window)."""
        now = time.time()
        connection_window = 60.0
        window_start = now - connection_window
        timestamps = self._connection_store[key]
        timestamps[:] = [t for t in timestamps if t > window_start]
        if len(timestamps) >= RATE_LIMIT_CONNECTION_MAX:
            return False
        timestamps.append(now)
        return True


class RedisRateLimiter:
    """Sliding-window rate limiter backed by Redis. Multi-worker safe.

    Uses a sorted set (ZSET) per key with timestamps as scores.
    Evicts old entries on each check to keep memory bounded.
    """

    def __init__(self, redis_url: str, is_production: bool = IS_PRODUCTION) -> None:
        self._is_production = is_production
        self._fallback = InMemoryRateLimiter()
        try:
            import redis
            self._redis = redis.Redis.from_url(
                redis_url, decode_responses=True, socket_connect_timeout=3
            )
            self._redis.ping()
            self._available = True
            logger.info("Redis rate limiter connected: %s", redis_url)
        except Exception as e:
            if self._is_production:
                logger.critical("Redis rate limiter connection failed in production: %s", e)
                raise RuntimeError(f"Required Redis connection failed in production: {e}")
            logger.warning(
                "Redis unavailable (%s) — falling back to in-memory rate limiting for development", e
            )
            self._redis = None  # type: ignore[assignment]
            self._available = False

    def is_allowed(self, key: str) -> bool:
        if not self._available:
            if self._is_production:
                logger.error("Redis unavailable in production — failing closed on rate limit check: %s", key)
                return False  # Fail closed in production
            return self._fallback.is_allowed(key)
        try:
            now = time.time()
            window_start = now - RATE_LIMIT_WINDOW
            pipe = self._redis.pipeline()
            pipe.zremrangebyscore(key, 0, window_start)
            pipe.zadd(key, {f"{now}": now})
            pipe.zcard(key)
            pipe.expire(key, RATE_LIMIT_WINDOW + 10)
            results = pipe.execute()
            count = results[2]
            return count <= RATE_LIMIT_MAX_REQUESTS
        except Exception as e:
            logger.warning("Redis rate limit check failed: %s", e)
            if self._is_production:
                logger.error("Failing closed for rate limit on error in production")
                return False  # Fail closed in production
            return self._fallback.is_allowed(key)

    def is_allowed_connection(self, key: str) -> bool:
        """Check connection-level rate limit (per minute, not per window)."""
        if not self._available:
            if self._is_production:
                logger.error("Redis unavailable in production — failing closed on connection check: %s", key)
                return False
            return self._fallback.is_allowed_connection(key)
        try:
            now = time.time()
            connection_window = 60.0
            window_start = now - connection_window
            pipe = self._redis.pipeline()
            pipe.zremrangebyscore(f"conn:{key}", 0, window_start)
            pipe.zadd(f"conn:{key}", {f"{now}": now})
            pipe.zcard(f"conn:{key}")
            pipe.expire(f"conn:{key}", 65)
            results = pipe.execute()
            count = results[2]
            return count <= RATE_LIMIT_CONNECTION_MAX
        except Exception as e:
            logger.warning("Redis connection rate limit check failed: %s", e)
            if self._is_production:
                logger.error("Failing closed for connection limit on error in production")
                return False
            return self._fallback.is_allowed_connection(key)


class RateLimiter:
    """Facade that selects Redis or in-memory based on REDIS_URL and environment."""

    def __init__(self) -> None:
        if REDIS_URL:
            self._backend: InMemoryRateLimiter | RedisRateLimiter = RedisRateLimiter(
                REDIS_URL, is_production=IS_PRODUCTION
            )
        elif IS_PRODUCTION:
            raise RuntimeError(
                "Refusing to start: REDIS_URL is not set in production. "
                "Multi-worker deployments MUST use Redis for shared rate limiting. "
                "Set REDIS_URL=redis://..."
            )
        else:
            self._backend = InMemoryRateLimiter()

        logger.info(
            "Rate limiter initialized: %s (window=%ds, max=%d per IP)",
            "redis" if REDIS_URL else "in-memory",
            RATE_LIMIT_WINDOW,
            RATE_LIMIT_MAX_REQUESTS,
        )

    def is_allowed(self, key: str) -> bool:
        return self._backend.is_allowed(key)

    def is_allowed_connection(self, key: str) -> bool:
        """Check connection-level rate limit. Returns True if connection is allowed."""
        return self._backend.is_allowed_connection(key)

    @staticmethod
    def error_response() -> dict:
        return {
            "status": "error",
            "error_code": "rate_limited",
            "message": "Too many requests. Please try again later.",
            "retry_after": RATE_LIMIT_WINDOW,
        }


# Singleton — import and use in middleware
rate_limiter = RateLimiter()
