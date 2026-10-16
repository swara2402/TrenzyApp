import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))
from backend.app.main import app

# Print all registered routes
for route in app.routes:
    if hasattr(route, 'path'):
        print(f"Path: {route.path}, Name: {route.name}")