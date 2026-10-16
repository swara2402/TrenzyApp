#!/usr/bin/env python3
"""Simple test to verify ai_router paths are correctly formatted."""
import sys
import os

# Add the backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Clear any cached imports
for module in list(sys.modules.keys()):
    if 'app.routes' in module:
        del sys.modules[module]

from app.routes.ai import router as ai_router
from app.routes.products import router as products_router

print("=== products_router (reference) ===")
print(f"products_router prefix: {products_router.prefix}")
for route in products_router.routes:
    if hasattr(route, 'path'):
        print(f"  {route.path} -> full path: {products_router.prefix}{route.path}")

print("\n=== ai_router (should match pattern) ===")
print(f"ai_router prefix: {ai_router.prefix}")
all_correct = True
for route in ai_router.routes:
    if hasattr(route, 'path'):
        full_path = ai_router.prefix + route.path
        expected_start = "/api/ai/"
        if not route.path.startswith("/ai/"):
            print(f"❌ INCORRECT: {route.path} -> full path: {full_path} (should start with /ai/)")
            all_correct = False
        else:
            print(f"✅ CORRECT: {route.path} -> full path: {full_path}")

if all_correct:
    print("\n✅ All AI routes have correct path prefixes!")
    sys.exit(0)
else:
    print("\n❌ Some AI routes have incorrect path prefixes!")
    sys.exit(1)