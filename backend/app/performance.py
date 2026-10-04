"""Performance optimization utilities for Trenzy.

Includes caching, query batching, and payload reduction strategies.
"""

import time
import logging
from functools import wraps
from typing import Any, Callable, Dict, List, Optional, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar('T')

class CacheEntry:
    """Simple TTL cache entry."""
    
    def __init__(self, value: Any, ttl: int = 300):
        self.value = value
        self.ttl = ttl
        self.created_at = time.time()
    
    def is_expired(self) -> bool:
        return time.time() - self.created_at > self.ttl
    
    def get(self) -> Optional[Any]:
        if self.is_expired():
            return None
        return self.value


class TTLCache:
    """Thread-unsafe but simple TTL cache for single-threaded async apps."""
    
    def __init__(self, max_size: int = 1000):
        self.cache: Dict[str, CacheEntry] = {}
        self.max_size = max_size
    
    def get(self, key: str) -> Optional[Any]:
        entry = self.cache.get(key)
        if entry is None:
            return None
        
        value = entry.get()
        if value is None:
            # Entry expired, remove it
            del self.cache[key]
            return None
        
        return value
    
    def set(self, key: str, value: Any, ttl: int = 300) -> None:
        if len(self.cache) >= self.max_size:
            # Simple eviction: remove oldest expired entries
            expired_keys = [
                k for k, v in self.cache.items()
                if v.is_expired()
            ]
            for k in expired_keys:
                del self.cache[k]
        
        self.cache[key] = CacheEntry(value, ttl)
    
    def clear(self, prefix: str = "") -> None:
        """Clear all keys with given prefix, or all if prefix is empty."""
        if not prefix:
            self.cache.clear()
        else:
            keys_to_delete = [k for k in self.cache.keys() if k.startswith(prefix)]
            for k in keys_to_delete:
                del self.cache[k]


# Global caches
_blend_cache = TTLCache()
_product_cache = TTLCache()
_color_cache = TTLCache()
_category_cache = TTLCache()


def cache_blend_results(ttl: int = 300):
    """Decorator to cache blend results by blend_id for N seconds.
    
    Args:
        ttl: Time-to-live in seconds (default 5 minutes)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(session, blend_id: str, *args, **kwargs):
            cache_key = f"blend:{blend_id}"
            cached = _blend_cache.get(cache_key)
            if cached is not None:
                logger.debug(f"Cache hit: blend results for {blend_id}")
                return cached
            
            result = func(session, blend_id, *args, **kwargs)
            _blend_cache.set(cache_key, result, ttl)
            logger.debug(f"Cached blend results for {blend_id} (ttl={ttl}s)")
            return result
        return wrapper
    return decorator


def invalidate_blend_cache(blend_id: str) -> None:
    """Invalidate blend result cache when it changes."""
    _blend_cache.cache.pop(f"blend:{blend_id}", None)
    logger.debug(f"Invalidated cache for blend {blend_id}")


def batch_fetch_products(session, product_ids: List[str]) -> Dict[str, Any]:
    """Batch-fetch products by ID to avoid N+1 queries.
    
    Args:
        session: SQLAlchemy session
        product_ids: List of product IDs to fetch
    
    Returns:
        Dict mapping product_id -> product object
    """
    from .models import Product
    
    if not product_ids:
        return {}
    
    # Deduplicate
    unique_ids = list(set(product_ids))
    
    # Check cache first
    cached = {}
    uncached_ids = []
    for pid in unique_ids:
        cached_prod = _product_cache.get(f"product:{pid}")
        if cached_prod is not None:
            cached[pid] = cached_prod
        else:
            uncached_ids.append(pid)
    
    if not uncached_ids:
        return cached
    
    # Fetch uncached products
    products = session.query(Product).filter(Product.id.in_(uncached_ids)).all()
    for prod in products:
        _product_cache.set(f"product:{prod.id}", prod, ttl=600)  # 10-min TTL
        cached[prod.id] = prod
    
    logger.debug(f"Batch-fetched {len(products)} products (cache hits: {len(cached) - len(products)})")
    return cached


def get_canonical_colors_cached(session) -> List[str]:
    """Get canonical colors from cache or database.
    
    Avoids repeated full-table scans of Product.color.
    """
    from .color_taxonomy import canonical_colors
    
    cache_key = "canonical_colors"
    cached = _color_cache.get(cache_key)
    if cached is not None:
        return cached
    
    colors = canonical_colors()
    _color_cache.set(cache_key, colors, ttl=3600)  # 1-hour TTL
    logger.debug(f"Cached {len(colors)} canonical colors")
    return colors


def get_canonical_categories_cached(session) -> List[str]:
    """Get canonical categories from cache or database.
    
    Avoids repeated full-table scans of Product.category.
    """
    from .category_taxonomy import canonical_categories
    
    cache_key = "canonical_categories"
    cached = _category_cache.get(cache_key)
    if cached is not None:
        return cached
    
    categories = canonical_categories()
    _category_cache.set(cache_key, categories, ttl=3600)  # 1-hour TTL
    logger.debug(f"Cached {len(categories)} canonical categories")
    return categories


def minimal_product_payload(product) -> dict:
    """Return minimal product data for list endpoints.
    
    Reduces response size and improves serialization speed.
    """
    return {
        "id": str(product.id),
        "name": product.name,
        "price": float(product.price) if product.price else None,
        "image_url": product.image_url,
        "category": product.category,
    }


def product_detail_payload(product) -> dict:
    """Return full product data for detail views."""
    return {
        "id": str(product.id),
        "name": product.name,
        "description": product.description,
        "price": float(product.price) if product.price else None,
        "image_url": product.image_url,
        "brand": product.brand,
        "category": product.category,
        "colors": product.colors or [],
        "sizes": product.sizes or [],
        "rating": product.rating,
        "tags": product.tags or [],
        "affiliate_url": product.affiliate_url,
        "in_stock": product.in_stock,
    }


def clear_all_caches() -> None:
    """Clear all performance caches. Call after bulk updates."""
    _blend_cache.clear()
    _product_cache.clear()
    _color_cache.clear()
    _category_cache.clear()
    logger.info("Cleared all performance caches")
