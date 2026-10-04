"""Test script to perfectly reproduce the original macOS libomp crash.

This script replicates the EXACT import order that caused the segmentation fault:
1. Import ai.py FIRST (which loads PyTorch at import time via its top-level imports)
2. THEN try to load LightGBM models from ModelManager (which tries to load libomp again)
3. This causes the duplicate libomp crash on macOS!
"""
print("🔴 Starting libomp crash test script...")
print("Step 1: Importing app.routes.ai (this loads PyTorch first)...")

# FIRST import the ai module - this triggers ALL its top-level imports including torch
from app.routes import ai
print("✅ Imported app.routes.ai - PyTorch is now loaded into the process!")

print("\nStep 2: Now trying to import ModelManager and load LightGBM models...")
print("This is where the crash happens because libomp is already loaded by PyTorch!")

# Now try to load LightGBM models - this will crash with duplicate libomp
from app.ai.model_manager import ModelManager
try:
    ModelManager.instance().load_models()
    print("❌ Unexpected: Model loading succeeded - no crash!")
except Exception as e:
    print(f"💥 CRASH OCCURRED as expected! Error: {e}")
    import traceback
    traceback.print_exc()