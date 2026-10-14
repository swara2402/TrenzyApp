import os

# Get all TRZ files
image_dir = "/Users/sam/Downloads/TrenzyApp/backend/uploads/product-images/images"
trz_files = [f for f in os.listdir(image_dir) if f.startswith('TRZ-') and f.endswith('.jpg')]

# Extract numbers and sort
file_numbers = []
for f in trz_files:
    try:
        num = int(f.split('-')[1].split('.')[0])
        file_numbers.append((num, f))
    except:
        pass

# Sort by number
file_numbers.sort(key=lambda x: x[0])

# Print last 20 files
print("Last 20 TRZ files (highest numbers):")
for num, f in file_numbers[-20:]:
    print(f"{num:04d}: {f}")

print(f"\nTotal TRZ files: {len(file_numbers)}")
print(f"Highest TRZ number: {file_numbers[-1][0] if file_numbers else 'None'}")
print(f"Lowest TRZ number: {file_numbers[0][0] if file_numbers else 'None'}")

# Check if 2001-2938 exist
missing = []
found = []
for num in range(2001, 2939):
    file = f"TRZ-{num:04d}.jpg"
    if os.path.exists(os.path.join(image_dir, file)):
        found.append(file)
    else:
        missing.append(file)

print(f"\nFiles in range 2001-2938 found: {len(found)}")
print(f"Files in range 2001-2938 missing: {len(missing)}")

# Check mens_products_valid.json count
import json
mens_file = "/Users/sam/Downloads/TrenzyApp/backend/data/mens_products_valid.json"
try:
    with open(mens_file, 'r') as f:
        mens_products = json.load(f)
    print(f"\nMen's products in mens_products_valid.json: {len(mens_products)}")
    # Extract unique image filenames from mens products
    mens_images = set()
    for product in mens_products:
        if 'mainImage' in product:
            filename = product['mainImage'].split('/')[-1]
            mens_images.add(filename)
    print(f"Unique men's image filenames: {len(mens_images)}")
except Exception as e:
    print(f"\nError reading mens_products_valid.json: {e}")