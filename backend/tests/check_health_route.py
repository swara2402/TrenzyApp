#!/usr/bin/env python3
"""Check if health router route is registered."""

from app.main import app
from app.routes import health

print(f"Health module has {len(health.router.routes)} routes in its own router")
print("\nMain app routes that mention 'health':")
for i, route in enumerate(app.routes):
    if hasattr(route, 'path'):
        path = getattr(route, 'path', '')
        if 'health' in path:
            print(f"  {path}")