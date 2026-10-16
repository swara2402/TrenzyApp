def test_debug_ai_routes2():
    """Debug what routes the ai module has when included with prefix."""
    from app.routes import ai
    print("\n=== AI ROUTER ROUTES (EXACT) ===")
    print(f"ai.router prefix: {ai.router.prefix}")
    print(f"Number of routes: {len(ai.router.routes)}")
    for i, route in enumerate(ai.router.routes):
        if hasattr(route, 'path'):
            print(f"  {i+1}. {route.path} | methods: {route.methods} | name: {route.name}")
        else:
            print(f"  {i+1}. NO PATH | type: {type(route).__name__}")
    print("================================\n")

    # Now check what the full path would be if we include it in main app with prefix="/ai"
    from fastapi import FastAPI
    test_app = FastAPI()
    test_app.include_router(ai.router, prefix="/ai")
    print("\n=== TEST APP ROUTES AFTER INCLUDING AI ROUTER WITH PREFIX=/ai ===")
    for i, route in enumerate(test_app.routes):
        if hasattr(route, 'path'):
            print(f"  {i+1}. {route.path}")
    print("================================\n")