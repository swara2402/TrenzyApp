"""Test that ai_router has the exact same path pattern as products_router.
products_router: prefix="/api" in APIRouter, endpoints start with "/products" → /api/products
ai_router: should have prefix="/api" in APIRouter, endpoints start with "/ai/" → /api/ai/...
This test verifies all ai_router endpoints have the correct path structure."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.routes.products import router as products_router
from app.routes.ai import router as ai_router

print("="*80)
print("Checking products_router path pattern (reference):")
print("="*80)
print(f"products_router prefix: {products_router.prefix}")
for route in products_router.routes:
    if hasattr(route, 'path'):
        full_path = f"{products_router.prefix}{route.path}"
        print(f"  products route: {route.path} → full path: {full_path}")

print("\n" + "="*80)
print("Checking ai_router path pattern (should match products_router):")
print("="*80)
print(f"ai_router prefix: {ai_router.prefix}")
all_ai_routes_correct = True
for route in ai_router.routes:
    if hasattr(route, 'path'):
        full_path = f"{ai_router.prefix}{route.path}"
        # Verify that every ai_router endpoint starts with "/ai/" - this is critical!
        if not route.path.startswith("/ai/"):
            print(f"❌ AI route INCORRECT: {route.path} → full path: {full_path} (missing leading /ai/)")
            all_ai_routes_correct = False
        else:
            print(f"✅ AI route correct: {route.path} → full path: {full_path}")

print("\n" + "="*80)
if all_ai_routes_correct:
    print("✅ ALL AI ROUTES HAVE CORRECT PATH PREFIXES!")
    print(f"Total ai_router endpoints: {len([r for r in ai_router.routes if hasattr(r, 'path')])}")
else:
    print("❌ Some AI routes have incorrect path prefixes!")
    sys.exit(1)