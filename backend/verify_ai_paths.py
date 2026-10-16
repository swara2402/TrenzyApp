#!/usr/bin/env python3
"""Verify that ai_router paths are correctly formatted after fixes."""
import sys
import os

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

# Clear any cached imports
if 'app.routes.ai' in sys.modules:
    del sys.modules['app.routes.ai']

from app.routes.ai import router as ai_router

print("=== VERIFYING AI ROUTER PATHS ===\n")
print(f"ai_router prefix: {ai_router.prefix}")
print(f"Number of routes: {len(ai_router.routes)}\n")

all_correct = True
for i, route in enumerate(ai_router.routes):
    if hasattr(route, 'path'):
        path = route.path
        full_path = f"{ai_router.prefix}{path}"
        if path.startswith("/ai/"):
            print(f"✅ [{i}] {path} → full path: {full_path} (CORRECT)")
        else:
            print(f"❌ [{i}] {path} → full path: {full_path} (INCORRECT - should start with /ai/)")
            all_correct = False

print(f"\n=== SUMMARY ===")
if all_correct:
    print("✅ All AI router paths are correctly formatted!")
    print(f"   All paths combine with router prefix '/api' to create: /api/ai/...")
else:
    print("❌ Some AI router paths have incorrect prefixes!")
    sys.exit(1)