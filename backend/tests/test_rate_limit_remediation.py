"""Tests for sliding window rate limiter and production fail-closed behaviors."""
import time
from app.rate_limit import InMemoryRateLimiter, RedisRateLimiter


def test_in_memory_rate_limiter_allows_under_limit():
    limiter = InMemoryRateLimiter()
    key = "test_ip_1"
    # Should allow up to max requests
    for _ in range(5):
        assert limiter.is_allowed(key) is True


def test_in_memory_rate_limiter_blocks_over_limit():
    limiter = InMemoryRateLimiter()
    key = "test_ip_2"
    from app.rate_limit import RATE_LIMIT_MAX_REQUESTS

    for _ in range(RATE_LIMIT_MAX_REQUESTS):
        assert limiter.is_allowed(key) is True

    # Next request should be blocked
    assert limiter.is_allowed(key) is False


def test_redis_rate_limiter_fails_closed_in_production():
    """In production mode, Redis unavailable fails closed (returns False)."""
    # Instantiate with unavailable Redis and is_production=True
    limiter = RedisRateLimiter("redis://127.0.0.1:1/0", is_production=False)
    # Manually simulate unavailable
    limiter._available = False
    limiter._is_production = True

    assert limiter.is_allowed("any_key") is False
    assert limiter.is_allowed_connection("any_key") is False
