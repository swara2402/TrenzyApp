import json
import shutil
from datetime import datetime

# Paths
JSON_PATH = "/Users/sam/Downloads/TrenzyApp/backend/data/products.json"
BACKUP_PATH = f"/Users/sam/Downloads/TrenzyApp/backend/data/products.json.backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

def main():
    # First create a backup
    print("📦 Creating backup of current products...")
    shutil.copyfile(JSON_PATH, BACKUP_PATH)
    print(f"✅ Backup created at: {BACKUP_PATH}")

    # Load all products
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        all_products = json.load(f)
    
    # Count original trenzy_ IDs
    original_trenzy = [p for p in all_products if p["id"].startswith("trenzy_")]
    print(f"\n📊 Original stats:")
    print(f"   - Original trenzy_ products: {len(original_trenzy)}")
    print(f"   - TRZ_M_ products to convert: {len(all_products) - len(original_trenzy)}")

    # Find the highest number in existing trenzy_ IDs to continue numbering
    max_trenzy_num = 0
    for p in original_trenzy:
        # Extract number from trenzy_XXXX
        try:
            num = int(p["id"].split("_")[1])
            if num > max_trenzy_num:
                max_trenzy_num = num
        except:
            continue
    
    print(f"\n🔢 Highest existing trenzy_ number: {max_trenzy_num}")
    print(f"   Starting new IDs at: {max_trenzy_num + 1}")

    # Convert all TRZ_M_ IDs to trenzy_XXXX (continuing the sequence)
    converted = 0
    new_ids = []
    for p in all_products:
        if p["id"].startswith("TRZ_M_"):
            max_trenzy_num += 1
            new_id = f"trenzy_{max_trenzy_num}"
            new_ids.append(f"{p['id']} → {new_id}")
            p["id"] = new_id
            converted += 1
    
    # Verify all IDs are now trenzy_ and unique
    all_ids = [p["id"] for p in all_products]
    unique_ids = set(all_ids)
    all_trenzy = all(p["id"].startswith("trenzy_") for p in all_products)

    print(f"\n✅ Conversion complete!")
    print(f"   Converted {converted} TRZ_M_ IDs to trenzy_ IDs")
    print(f"   All products now use trenzy_ prefix: {all_trenzy}")
    print(f"   All IDs are unique: {len(all_ids) == len(unique_ids)}")

    # Save the updated catalog
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(all_products, f, ensure_ascii=False, indent=2)
    
    print(f"\n💾 Updated catalog saved to: {JSON_PATH}")

    # Final verification
    final_trenzy = sum(1 for p in all_products if p["id"].startswith("trenzy_"))
    print(f"\n📊 Final catalog stats:")
    print(f"   TOTAL products: {len(all_products)}")
    print(f"   All products use trenzy_ prefix: {final_trenzy} (expected 2938)")

if __name__ == "__main__":
    main()