"""Debug script to check what routes are actually registered in the main app.
This will show us if ai_router's endpoints are properly expanded to APIRoutes."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from fastapi.routing import APIRoute
from app.main import app  # Import the actual FastAPI app from main.py

print("="*80)
print("DEBUG: All routes registered in main app:")
print("="*80)

count = 0
ai_routes_found = 0
products_routes_found = 0

for i, route in enumerate(app.routes):
    count += 1
    route_type_name = type(route).__name__
    # Check what type of route this is
    if isinstance(route, APIRoute):
        # This is a fully expanded APIRoute - should exist for all working routes
        if hasattr(route, 'path'):
            if "/ai/" in route.path:
                ai_routes_found += 1
                print(f"✅ [{i}] APIRoute (expanded) AI Route: {route.path} [{','.join(route.methods)}]")
            elif "/products" in route.path:
                products_routes_found += 1
                print(f"✅ [{i}] APIRoute (expanded) Products Route: {route.path} [{','.join(route.methods)}]")
            else:
                print(f"  [{i}] APIRoute (expanded): {route.path} [{','.join(route.methods)}]")
    elif route_type_name == "_IncludedRouter":
        # This is a router that hasn't been expanded yet - this is the issue!
        print(f"⚠️  [{i}] _IncludedRouter found: router={route.router} prefix={route.prefix}")
        # Check if this is the ai_router or products_router
        if hasattr(route.router, 'tags'):
            print(f"     Router tags: {route.router.tags}")
            if "ai" in route.router.tags:
                print(f"     ❌ This is the ai_router - it's still an _IncludedRouter, not expanded!")
            if "products" in route.router.tags:
                print(f"     ℹ️ This is the products_router - is it also an _IncludedRouter?")
    else:
        # Other types (Mount, Route, etc.)
        try:
            path = getattr(route, 'path', 'no-path')
            print(f"ℹ️  [{i}] {route_type_name}: path={path}")
        except:
            print(f"ℹ️  [{i}] {route_type_name}: (could not get path)")

print("\n" + "="*80)
print(f"SUMMARY:")
print(f"  Total routes in main app: {count}")
print(f"  Products routes found: {products_routes_found}")
print(f"  AI routes found: {ai_routes_found}")
print("="*80)

if ai_routes_found == 0:
    print("\n❌ PROBLEM: No AI routes found in main app! This is why we get 404s.")
    print("Check if ai_router is properly imported and included in app.include_router()")
else:
    print(f"\n✅ AI routes found! That's good.")