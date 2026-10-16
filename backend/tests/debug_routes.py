from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_print_all_routes():
    """Print all registered routes to debug 404 issues."""
    print("\n" + "="*80)
    print(f"Total routes registered in main app: {len(app.routes)}")
    print("="*80)
    
    # First check what routes are in products_router before it's included
    from app.routes import products_router
    print(f"\n[BEFORE INCLUSION] products_router has {len(products_router.routes)} routes")
    if products_router.routes:
        first_products_route = products_router.routes[0]
        print(f"First products_router route path: {getattr(first_products_route, 'path', 'NO PATH')}")
    
    # Now check ai_router
    from app.routes import ai_router
    print(f"\n[BEFORE INCLUSION] ai_router has {len(ai_router.routes)} routes")
    if ai_router.routes:
        first_ai_route = ai_router.routes[0]
        print(f"First ai_router route path: {getattr(first_ai_route, 'path', 'NO PATH')}")
    
    # Count APIRoute objects (actual HTTP endpoints)
    api_routes = []
    for i, route in enumerate(app.routes):
        # Print type of every route to understand what's being added
        print(f"\nRoute #{i+1}: type={type(route).__name__}, has_path={hasattr(route, 'path')}, has_methods={hasattr(route, 'methods')}")
        # Check if this is the products_router _IncludedRouter
        if hasattr(route, 'router') and route.router is products_router:
            print("  → This is the products_router IncludedRouter!")
            # Print its subroutes
            if hasattr(route.router, 'routes'):
                print(f"  → products_router has {len(route.router.routes)} sub-routes")
                for j, subroute in enumerate(route.router.routes[:3]):  # Print first 3
                    subpath = getattr(subroute, 'path', 'NO PATH')
                    print(f"    Subroute #{j+1}: {subpath}")
        # Check if this is the ai_router _IncludedRouter
        if hasattr(route, 'router') and route.router is ai_router:
            print("  → This is the ai_router IncludedRouter!")
            if hasattr(route.router, 'routes'):
                print(f"  → ai_router has {len(route.router.routes)} sub-routes")
                for j, subroute in enumerate(route.router.routes[:3]):  # Print first 3
                    subpath = getattr(subroute, 'path', 'NO PATH')
                    print(f"    Subroute #{j+1}: {subpath}")
        # Only process APIRoute objects (actual HTTP endpoints), skip Mount objects etc.
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            api_routes.append(route)
            methods = ", ".join(sorted(route.methods))
            print(f"  → APIRoute: PATH: {route.path:<50} METHODS: {methods}")
    
    print("\n" + "="*80)
    print(f"Total HTTP API routes found: {len(api_routes)}")
    print("="*80)
    
    # Check if any /api/ai routes exist
    ai_routes = [r for r in api_routes if "/ai" in r.path]
    print(f"\nFound {len(ai_routes)} routes containing '/ai':")
    for route in ai_routes:
        print(f"  {route.path}")