"""Server-side launch gates for features intentionally deferred past beta.

Beta is discovery/inspiration-only. Affiliate links, cart/checkout, purchases,
and other commerce flows remain in the repository for a later phase, but are
disabled unless explicitly enabled in the deployment environment.
"""
from __future__ import annotations

import os

from fastapi import HTTPException


BETA_COMMERCE_ENABLED = (
    os.getenv("TRENZY_BETA_COMMERCE_ENABLED", "false").strip().lower()
    in {"1", "true", "yes", "on"}
)


def require_beta_commerce() -> None:
    """Fail closed while cart/checkout/purchase history are post-launch."""
    if not BETA_COMMERCE_ENABLED:
        raise HTTPException(
            status_code=404,
            detail="Commerce checkout is not enabled in the current Trenzy release.",
        )
