"""Create a minimal FastAPI app with ONLY the ai_router to test if routes work."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.routes.ai import router as ai_router

# Create minimal app
app = FastAPI()
app.include_router(ai_router)

client = TestClient(app)

print("="*80)
print("Testing minimal app with only ai_router...")
print("="*80)

# List all routes in this minimal app
print("\nRegistered routes in minimal app:")
for route in app.routes:
    if hasattr(route, 'path'):
        print(f"  {route.path} [{','.join(route.methods) if hasattr(route, 'methods') else 'no-methods'}]")

# Test the /api/ai/models/health endpoint
print("\nTesting GET /api/ai/models/health...")
try:
    response = client.get("/api/ai/models/health")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
except Exception as e:
    print(f"Error: {e}")

# Test if the ai_router's own routes are accessible
print("\nChecking ai_router's internal routes:")
for route in ai_router.routes:
    if hasattr(route, 'path'):
        print(f"  ai_router internal route: {route.path}")