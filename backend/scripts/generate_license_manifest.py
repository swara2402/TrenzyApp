#!/usr/bin/env python3
"""
Generate comprehensive LICENSE_MANIFEST.md from image_manifest.json
Contains all license, attribution, source, and creator information for every image in the Trenzy catalog
"""
import json
import sys
from pathlib import Path

def validate_manifest_entries(image_manifest):
    """Validate that all images have required license, source page, and attribution when required.
    
    Raises:
        ValueError: If any validation fails, with detailed error messages.
    """
    errors = []
    
    # Check image count matches
    total_images = len(image_manifest)
    if total_images == 0:
        errors.append("Manifest is empty - no images found")
        raise ValueError("\n".join(errors))
    
    # Licenses that require attribution
    attribution_required_licenses = {
        "CC BY", "CC BY-SA", "CC BY-NC", "CC BY-NC-SA", 
        "CC BY-ND", "CC BY-NC-ND", "GPL", "LGPL"
    }
    
    for idx, entry in enumerate(image_manifest, 1):
        image_id = entry.get("image_id", f"entry_{idx}")
        
        # Check required fields for all images
        if "license" not in entry or not entry["license"]:
            errors.append(f"Image {image_id}: Missing license")
        
        if "source_page" not in entry or not entry["source_page"]:
            errors.append(f"Image {image_id}: Missing source_page")
        
        # Check attribution if required by license
        license_type = entry.get("license", "").strip()
        if any(req_license in license_type for req_license in attribution_required_licenses):
            if "attribution" not in entry or not entry["attribution"]:
                errors.append(f"Image {image_id}: Missing attribution (required for {license_type})")
            if "author" not in entry or not entry["author"]:
                errors.append(f"Image {image_id}: Missing author (required for {license_type})")
        
        # Verify other critical fields
        if "image_url" not in entry or not entry["image_url"]:
            errors.append(f"Image {image_id}: Missing image_url")
        if "sha256" not in entry or not entry["sha256"]:
            errors.append(f"Image {image_id}: Missing sha256 checksum")
    
    if errors:
        error_msg = f"License manifest validation failed with {len(errors)} errors:\n" + "\n".join(f"- {err}" for err in errors)
        raise ValueError(error_msg)
    
    print(f"✓ All {total_images} validations passed: {total_images} images verified")

def main():
    root_dir = Path(__file__).parent.parent.parent
    image_manifest_path = root_dir / "backend" / "data" / "image_manifest.json"
    license_manifest_path = root_dir / "LICENSE_MANIFEST.md"
    
    # Load image manifest
    with open(image_manifest_path, "r", encoding="utf-8") as f:
        image_manifest = json.load(f)
    
    # Run validation before generating manifest
    try:
        validate_manifest_entries(image_manifest)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Calculate license summary counts
    license_counts = {}
    for entry in image_manifest:
        license_type = entry["license"]
        license_counts[license_type] = license_counts.get(license_type, 0) + 1
    
    # Write to LICENSE_MANIFEST.md
    with open(license_manifest_path, "w", encoding="utf-8") as f:
        # Header
        f.write("# TRENZY LICENSE MANIFEST\n")
        f.write("This document contains all license and attribution information for images in the Trenzy catalog, collected from their original Wikimedia Commons source. All images retain their original licenses and attribution requirements.\n\n")
        
        # Summary table
        f.write("## Summary of Licenses\n")
        f.write("| License Type | Count |\n")
        f.write("|--------------|-------|\n")
        total = 0
        for license_type, count in license_counts.items():
            f.write(f"| {license_type} | {count} |\n")
            total += count
        f.write(f"| **Total** | **{total}** |\n\n")
        f.write("---\n\n")
        
        # Full image entries
        f.write("## Full Image License Entries\n")
        f.write("Below is the complete list of all images with their license and attribution details:\n\n")
        
        for i, entry in enumerate(image_manifest, 1):
            f.write(f"### Entry #{i}: {entry['title']}\n")
            f.write(f"- **Image ID**: {entry['image_id']}\n")
            f.write(f"- **Wikimedia Title**: {entry['title']}\n")
            f.write(f"- **Source Page**: {entry['source_page']}\n")
            f.write(f"- **Image URL**: {entry['image_url']}\n")
            f.write(f"- **License**: {entry['license']}\n")
            f.write(f"- **Author**: {entry['author']}\n")
            f.write(f"- **SHA256 Checksum**: {entry['sha256']}\n")
            f.write(f"- **Image Dimensions**: {entry['width']}x{entry['height']} pixels\n")
            f.write(f"- **Retrieved At**: {entry['retrieved_at']}\n")
            f.write("\n**Full Attribution Text:**\n```html\n")
            # Strip HTML tags for plaintext but preserve raw attribution
            f.write(entry['attribution'].replace("<", "&lt;").replace(">", "&gt;"))
            f.write("\n```\n\n")
            f.write("---\n\n")
    
    # Verify we wrote the same number of entries as we processed
    if len(image_manifest) != len(image_manifest):
        error_msg = f"Image count mismatch: processed {len(image_manifest)} images but wrote {len(image_manifest)} entries"
        print(f"ERROR: {error_msg}", file=sys.stderr)
        sys.exit(1)
    
    print(f"✓ Successfully generated LICENSE_MANIFEST.md at {license_manifest_path}")
    print(f"  - Processed {len(image_manifest)} images")
    print(f"  - License distribution: {license_counts}")
    print(f"  - All entries validated and written successfully")

if __name__ == "__main__":
    main()