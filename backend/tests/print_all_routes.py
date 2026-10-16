#!/usr/bin/env python3
"""Print all registered routes in the main app to debug path issues."""

from app.main import app

def print_all_routes():
    print(f"\n=== TOTAL ROUTES IN MAIN APP: {len(app.routes)} ===\n")
    print("=== ALL REGISTERED HTTP ROUTES (APIRoute objects): ===")
    for i, route in enumerate(app.routes):
        if hasattr(route, 'path'):
            methods = getattr(route, 'methods', set())
            path = getattr(route, 'path', 'NO PATH')
            name = getattr(route, 'name', 'NO NAME')
            print(f"  {i+1}. {path} | Methods: {methods} | Name: {name}")
    
    print("\n=== ROUTES THAT MENTION 'ai' OR 'stylist': ===")
    for i, route in enumerate(app.routes):
        if hasattr(route, 'path'):
            path = getattr(route, 'path', '')
            if 'ai' in path or 'stylist' in path:
                methods = getattr(route, 'methods', set())
                print(f"  FOUND AI-RELATED ROUTE: {path} | Methods: {methods}")

if __name__ == "__main__":
    print_all_routes()