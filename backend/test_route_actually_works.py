#!/usr/bin/env python3
"""Test if the main app can actually serve the /api/ai/models/health endpoint despite _IncludedRouter appearance."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# First test a known working endpoint - let's test the health endpoint
print("=== TESTING KNOWN WORKING HEALTH ENDPOINT FIRST ===\n")
try:
    response = client.get("/api/health")
    print(f"GET /api/health - Status: {response.status_code}")
    if response.status_code == 200:
        print("✅ Health endpoint works!")
    else:
        print(f"❌ Health endpoint failed: {response.text}")
except Exception as e:
    print(f"❌ Exception calling health endpoint: {e}")

print("\n=== TESTING AI MODELS HEALTH ENDPOINT ===\n")
# We need to add auth headers since the ai endpoints require authentication
from tests.conftest import auth_headers  # Import the auth fixture

try:
    headers = auth_headers()
    response = client.get("/api/ai/models/health", headers=headers)
    print(f"GET /api/ai/models/health - Status: {response.status_code}")
    if response.status_code == 200:
        print("✅ AI models health endpoint works!")
        print(f"   Response: {response.json()}")
    else:
        print(f"❌ AI models health endpoint failed: {response.text}")
except Exception as e:
    print(f"❌ Exception calling AI endpoint: {e}")
    import traceback
    traceback.print_exc()