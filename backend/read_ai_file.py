#!/usr/bin/env python3
"""Read the ai.py file directly to verify the changes were saved."""
import os

ai_file_path = os.path.join(os.path.dirname(__file__), 'app', 'routes', 'ai.py')

with open(ai_file_path, 'r') as f:
    lines = f.readlines()

# Find the endpoints section
print("=== READING FIRST 10 ENDPOINT DEFINITIONS FROM ai.py ===\n")
count = 0
for line in lines:
    if '@router.get' in line or '@router.post' in line:
        print(line.strip())
        count += 1
        if count >= 20:
            break

print(f"\nFound {count} endpoint definitions")