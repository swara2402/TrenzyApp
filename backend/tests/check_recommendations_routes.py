#!/usr/bin/env python3
"""Check if recommendations router routes are registered."""

from app.main import app
from app.routes import recommendations

print(f"Recommendations module has {len(recommendations.router.routes)} routes in its own router")
print("\nMain app routes that mention 'recommendation' or 'recommend':")
for i, route in enumerate(app.routes):
    if hasattr(route, 'path'):
        path = getattr(route, 'path', '')
        if 'recommend' in path:
            print(f"  {path}")