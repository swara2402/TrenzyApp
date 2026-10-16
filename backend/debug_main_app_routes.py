#!/usr/bin/env python3
"""Debug the main app to see if ai_router routes are properly expanded."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

# Clear import cache
for module in list(sys.modules.keys()):
    if 'app' in module:
        del sys.modules[module]

from app.main import app

print("=== MAIN APP ROUTE DEBUG ===\n")
print(f"Total routes in main app: {len(app.routes)}")
print(f"\nListing all routes with their types:\n")

ai_routes_found = 0
products_routes_found = 0
included_routers_found = 0

for i, route in enumerate(app.routes):
    route_type = type(route).__name__
    path = getattr(route, 'path', 'NO PATH')
    methods = getattr(route, 'methods', None)
    
    if route_type == 'APIRoute':
        if '/ai/' in path:
            print(f"✅ [{i}] APIRoute: {path} (methods: {methods}) - AI route found!")
            ai_routes_found += 1
        elif '/products' in path:
            print(f"✅ [{i}] APIRoute: {path} (methods: {methods}) - Products route found!")
            products_routes_found += 1
        else:
            print(f"ℹ️  [{i}] APIRoute: {path}")
    elif route_type == '_IncludedRouter':
        print(f"⚠️  [{i}] _IncludedRouter found: tags={getattr(route, 'tags', 'N/A')}, prefix={getattr(route, 'prefix', 'N/A')}")
        included_routers_found += 1
        # Check if this is the ai_router
        if hasattr(route, 'tags') and 'ai' in getattr(route, 'tags', []):
            print(f"     This is the ai_router! Its internal routes:")
            for internal_route in route.routes:
                internal_path = getattr(internal_route, 'path', 'NO PATH')
                print(f"       - {internal_path}")
    else:
        print(f"ℹ️  [{i}] {route_type}: {path}")

print(f"\n=== SUMMARY ===")
print(f"AI routes found as APIRoutes: {ai_routes_found}")
print(f"Products routes found as APIRoutes: {products_routes_found}")
print(f"_IncludedRouter instances found: {included_routers_found}")

if ai_routes_found == 0 and included_routers_found > 0:
    print("\n❌ PROBLEM IDENTIFIED: ai_router is still an _IncludedRouter and hasn't been expanded into APIRoutes!")
    print("   This is the cause of the 404 errors.")
elif ai_routes_found > 0:
    print(f"\n✅ SUCCESS: Found {ai_routes_found} AI routes as proper APIRoutes!")