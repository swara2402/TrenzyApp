#!/usr/bin/env python3
"""Pre-release validation script for Trenzy.

Checks every hard requirement that must pass before shipping to real users.
Exits with code 0 only when all checks pass (or are acceptable warnings).
Exits with code 1 if any BLOCKER is found.

Run from the repository root:
    python scripts/validate_release.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

BLOCKERS: list[str] = []
WARNINGS: list[str] = []


def check(condition: bool, blocker_msg: str, warn_msg: str | None = None) -> None:
    if not condition:
        if warn_msg is None:
            BLOCKERS.append(blocker_msg)
        else:
            WARNINGS.append(warn_msg or blocker_msg)


# ──────────────────────────────────────────────────────────────
# 1. Firebase config – no REPLACE_ME placeholders
# ──────────────────────────────────────────────────────────────

def check_firebase_config() -> None:
    path = ROOT / "assets" / "firebase_options.json"
    if not path.exists():
        BLOCKERS.append(f"[Firebase] assets/firebase_options.json not found")
        return

    raw = path.read_text()
    bad = re.findall(r"REPLACE_ME|com\.yourcompany\.trenzy|CHANGE_ME", raw)
    if bad:
        BLOCKERS.append(
            f"[Firebase] assets/firebase_options.json contains {len(bad)} placeholder(s): "
            f"{', '.join(set(bad))}. "
            "Update with real values from Firebase Console before release."
        )

    try:
        cfg = json.loads(raw)
        for platform in ("android", "ios", "macos"):
            p = cfg.get(platform, {})
            app_id = p.get("appId", "")
            if not app_id or "REPLACE_ME" in app_id:
                BLOCKERS.append(
                    f"[Firebase] Platform '{platform}' appId is missing or placeholder. "
                    "Native Firebase auth will fail."
                )
        for platform in ("ios", "macos"):
            p = cfg.get(platform, {})
            for field in ("iosClientId", "iosBundleId"):
                val = p.get(field, "")
                if not val or "REPLACE_ME" in val or "yourcompany" in val:
                    BLOCKERS.append(
                        f"[Firebase] Platform '{platform}'.{field} is missing or placeholder."
                    )
    except json.JSONDecodeError as exc:
        BLOCKERS.append(f"[Firebase] firebase_options.json is invalid JSON: {exc}")


# ──────────────────────────────────────────────────────────────
# 2. Search routes – no stub placeholders
# ──────────────────────────────────────────────────────────────

def check_search_stubs() -> None:
    path = ROOT / "backend" / "app" / "routes" / "search.py"
    if not path.exists():
        WARNINGS.append("[Search] backend/app/routes/search.py not found")
        return

    content = path.read_text()
    stub_patterns = [
        (r"similarity_score.*0\.85", "visual_search returns hardcoded score 0.85"),
        (r"relevance_score.*0\.9", "semantic_search returns hardcoded score 0.9"),
        (r"# Visual search implementation using FashionCLIP embeddings\n\s+stmt = select\(Product\)\.order_by",
         "visual_search is still a stub (newest-products fallback)"),
        (r"# Semantic search implementation using text embeddings\n\s+stmt = select\(Product\)\.order_by",
         "semantic_search is still a stub (newest-products fallback)"),
    ]
    for pattern, description in stub_patterns:
        if re.search(pattern, content):
            BLOCKERS.append(f"[Search] {description}. Wire up the real embedding service.")


# ──────────────────────────────────────────────────────────────
# 3. Health endpoint – must check catalog, embeddings, migrations
# ──────────────────────────────────────────────────────────────

def check_health_gates() -> None:
    path = ROOT / "backend" / "app" / "routes" / "health.py"
    if not path.exists():
        WARNINGS.append("[Health] backend/app/routes/health.py not found")
        return

    content = path.read_text()
    required_checks = {
        "catalog": "catalog_",
        "embeddings": "embedding",
        "migrations": "migration",
        "firebase": "firebase",
    }
    for label, pattern in required_checks.items():
        if pattern not in content:
            BLOCKERS.append(
                f"[Health] /api/health/ready does not check '{label}'. "
                "An empty/broken deployment can still pass the readiness probe."
            )


# ──────────────────────────────────────────────────────────────
# 4. Auth rate limiting – must not be process-local only in production
# ──────────────────────────────────────────────────────────────

def check_auth_rate_limit() -> None:
    path = ROOT / "backend" / "app" / "routes" / "auth.py"
    if not path.exists():
        WARNINGS.append("[Auth] backend/app/routes/auth.py not found")
        return

    content = path.read_text()
    if "_redis_client" not in content and "_check_auth_rate_redis" not in content:
        BLOCKERS.append(
            "[Auth] Authentication rate limiter is process-local only. "
            "This is ineffective when running multiple Gunicorn workers. "
            "Implement Redis-backed rate limiting."
        )


# ──────────────────────────────────────────────────────────────
# 5. Catalog quality – at least 1 product must have an image_url
#    (checked here against the catalog JSON files, not the DB)
# ──────────────────────────────────────────────────────────────

def check_catalog_files() -> None:
    catalog_dir = ROOT / "backend" / "data"
    if not catalog_dir.exists():
        WARNINGS.append("[Catalog] backend/data/ directory not found; skipping catalog check.")
        return

    json_files = list(catalog_dir.glob("*.json"))
    if not json_files:
        WARNINGS.append("[Catalog] No JSON catalog files found in backend/data/. Populate the catalog.")
        return

    total = 0
    with_image = 0
    for f in json_files:
        try:
            products = json.loads(f.read_text())
            if isinstance(products, list):
                for p in products:
                    total += 1
                    if p.get("image_url"):
                        with_image += 1
        except Exception:
            WARNINGS.append(f"[Catalog] Could not parse {f.name}")

    if total == 0:
        BLOCKERS.append("[Catalog] Catalog files are empty. Add real products before release.")
    elif with_image == 0:
        BLOCKERS.append(
            f"[Catalog] {total} products found but none have 'image_url'. "
            "Visual search and thumbnails will be broken."
        )
    elif with_image < total * 0.8:
        WARNINGS.append(
            f"[Catalog] Only {with_image}/{total} products have image_url "
            f"({100*with_image//total}%). Consider filling in missing images."
        )


# ──────────────────────────────────────────────────────────────
# 6. Backend .env – production env example has no simulation payments
# ──────────────────────────────────────────────────────────────

def check_prod_env_example() -> None:
    path = ROOT / "backend" / ".env.production.example"
    if not path.exists():
        WARNINGS.append("[Env] backend/.env.production.example not found")
        return

    content = path.read_text()
    if "PAYMENTS_MODE=simulation" in content:
        BLOCKERS.append(
            "[Env] .env.production.example sets PAYMENTS_MODE=simulation. "
            "Change it to razorpay to avoid accidental simulation mode in production."
        )


# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

def main() -> None:
    check_firebase_config()
    check_search_stubs()
    check_health_gates()
    check_auth_rate_limit()
    check_catalog_files()
    check_prod_env_example()

    print("\n=== Trenzy Release Validation ===\n")

    if WARNINGS:
        print(f"⚠️  WARNINGS ({len(WARNINGS)}):")
        for w in WARNINGS:
            print(f"  • {w}")
        print()

    if BLOCKERS:
        print(f"🚫 BLOCKERS ({len(BLOCKERS)}) — fix these before releasing to real users:")
        for b in BLOCKERS:
            print(f"  ✗ {b}")
        print()
        print("❌ Release validation FAILED. Not ready for real users.\n")
        sys.exit(1)

    print("✅ Release validation PASSED. All checks OK.\n")


if __name__ == "__main__":
    main()
