#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))
os.environ["APP_ENV"] = "development"
os.environ["DEV_AUTH_BYPASS"] = "true"
os.environ["DEV_AUTH_UID"] = "test-user-1"
os.environ["DEV_AUTH_SECRET"] = "test-dev-secret"
os.environ["FIREBASE_SERVICE_ACCOUNT_FILE"] = "/dev/null"
os.environ["TRENZY_TEST_DB"] = "1"

# Import after setting env vars
from backend.app.main import app

print("\nAll registered routes in the app:")
for i, route in enumerate(app.routes):
    if hasattr(route, 'path'):
        print(f"{i+1}. {route.path} -> {route.name}")
print(f"\nTotal routes: {len(app.routes)}")

# Check if ai router is in the included routers
print("\nChecking AI router:")
from backend.app.routes import ai
print(f"ai module has router attribute: {hasattr(ai, 'router')}")
if hasattr(ai, 'router'):
    print(f"ai.router prefix: {ai.router.prefix}")
    print(f"ai.router has {len(ai.router.routes)} routes")
    for i, route in enumerate(ai.router.routes):
        if hasattr(route, 'path'):
            print(f"  {i+1}. {ai.router.prefix}{route.path} -> {route.name}")