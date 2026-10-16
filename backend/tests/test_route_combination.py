from fastapi import APIRouter, FastAPI
from app.routes.ai import router as ai_router
from app.routes.products import router as products_router

def test_route_combination():
    """Test how FastAPI combines router prefixes with endpoint paths."""
    print("\n" + "="*80)
    print("Testing FastAPI router prefix combination")
    print("="*80)
    
    # Create a minimal test app
    app = FastAPI()
    
    # First check what's in ai_router BEFORE including
    print(f"\nBefore including ai_router:")
    print(f"ai_router.prefix = {ai_router.prefix}")
    for i, route in enumerate(ai_router.routes[:3]):
        print(f"  Route {i}: path in router = {route.path}")
    
    # Include the ai_router
    app.include_router(ai_router)
    
    # Now check what's in the app's routes
    print(f"\nAfter including ai_router, app has {len(app.routes)} routes:")
    for i, route in enumerate(app.routes):
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            print(f"  APIRoute: {route.path}")
    
    # Now do the same for products_router (which works)
    print(f"\n\nNow test products_router (which works in production):")
    app2 = FastAPI()
    print(f"products_router.prefix = {products_router.prefix}")
    for i, route in enumerate(products_router.routes[:3]):
        print(f"  Route {i}: path in router = {route.path}")
    
    app2.include_router(products_router)
    print(f"\nAfter including products_router, app2 has {len(app2.routes)} routes:")
    for i, route in enumerate(app2.routes):
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            print(f"  APIRoute: {route.path}")