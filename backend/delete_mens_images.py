import os

image_dir = "/Users/sam/Downloads/TrenzyApp/backend/uploads/product-images/images"

# Delete all files from TRZ-2001.jpg to TRZ-2938.jpg
deleted = 0
skipped = 0

for num in range(2001, 2939):
    filename = f"TRZ-{num:04d}.jpg"
    filepath = os.path.join(image_dir, filename)
    if os.path.exists(filepath):
        try:
            os.remove(filepath)
            print(f"Deleted: {filename}")
            deleted += 1
        except Exception as e:
            print(f"Failed to delete {filename}: {e}")
            skipped += 1
    else:
        print(f"File not found: {filename}")
        skipped += 1

print(f"\nSummary:")
print(f"Successfully deleted: {deleted} files")
print(f"Skipped/missing/failed: {skipped} files")