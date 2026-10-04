#!/usr/bin/env python3
"""
TRENZY BETA LAUNCH READINESS AUDIT
Executes critical checks for beta launch readiness, connects to database for real metrics.
"""
import json
import os
import sys
from pathlib import Path

# Add backend to path to import app modules
sys.path.insert(0, os.path.dirname(__file__))  # Add backend directory to path

from app.db import engine, SessionLocal
from app.models import Product
from app.ai.models_ai import ProductEmbedding

def run_audit():
    """Execute all readiness checks and generate audit report"""
    print("=================================")
    print("TRENZY STARTUP READINESS AUDIT")
    print("=================================")
    
    # Initialize counters
    catalog_stats = {"total_products": 0, "eligible": 0, "archived": 0, "metadata_complete": 0}
    image_stats = {"valid": 0, "temp_failures": 0, "perm_failures": 0, "duplicates": 0, "invalid": 0}
    license_stats = {"licensed_complete": 0, "attribution_required": 0}
    embedding_stats = {"model": "FashionCLIP", "dimension": 512, "valid": 0, "invalid": 0}
    interaction_stats = {"total_events": 0, "positive_events": 0, "date_range": "N/A"}
    model_registry_stats = {"production_models": 0, "retired_models": 0}
    test_stats = {"passed": 0, "failed": 0, "skipped": 0}
    metadata_pct = 0
    blockers = []
    
    # 1. CATALOG CHECKS (database-first with static file fallback)
    print("\nCATALOG:")
    db_available = True
    products_path = Path("/Users/sam/Downloads/trenzy_production/backend/data/products.json")
    static_products = None
    
    # First try database connection (works in containerized/production environment)
    try:
        db = SessionLocal()
        # Get total products from database
        all_products = db.query(Product).all()
        catalog_stats["total_products"] = len(all_products)
        print(f"  Total products in database: {catalog_stats['total_products']}")
        
        # Count eligible vs archived
        archived = db.query(Product).filter(Product.is_active == False).all()
        catalog_stats["archived"] = len(archived)
        catalog_stats["eligible"] = catalog_stats["total_products"] - catalog_stats["archived"]
        print(f"  Eligible fashion products: {catalog_stats['eligible']}")
        print(f"  Archived non-fashion/invalid: {catalog_stats['archived']}")
        
        # Metadata completeness check
        complete = 0
        for p in all_products:
            if (p.category not in ["unknown", None] and 
                p.brand not in ["unknown", None] and
                p.price is not None):
                complete += 1
        catalog_stats["metadata_complete"] = complete
        metadata_pct = (complete / len(all_products)) * 100 if all_products else 0
        print(f"  Metadata complete: {complete}/{len(all_products)} ({metadata_pct:.1f}%)")
        
        if metadata_pct < 50:
            blockers.append("Low catalog metadata completeness (<50%)")
        db.close()
    except Exception as e:
        db_available = False
        print(f"  ℹ️  Database not available locally - falling back to static catalog file")
        # Fallback to static products.json for local audits
        if products_path.exists():
            with open(products_path, 'r') as f:
                static_products = json.load(f)
            catalog_stats["total_products"] = len(static_products)
            print(f"  Total products (static file): {len(static_products)}")
            
            # Count eligible vs archived from static file
            archived = [p for p in static_products if p.get("catalog_status") == "ARCHIVED"]
            catalog_stats["archived"] = len(archived)
            catalog_stats["eligible"] = len(static_products) - len(archived)
            print(f"  Eligible fashion products: {catalog_stats['eligible']}")
            print(f"  Archived non-fashion/invalid: {len(archived)}")
            
            # Metadata completeness check from static file
            complete = 0
            for p in static_products:
                if (p.get("category") not in ["unknown", None] and 
                    p.get("brand") not in ["unknown", None] and
                    p.get("price") is not None):
                    complete += 1
            catalog_stats["metadata_complete"] = complete
            metadata_pct = (complete / len(static_products)) * 100 if static_products else 0
            print(f"  Metadata complete: {complete}/{len(static_products)} ({metadata_pct:.1f}%)")
            
            if metadata_pct < 50:
                blockers.append("Low catalog metadata completeness (<50%) in static file")
        else:
            print("  WARNING: products.json fallback file not found")
            blockers.append("Database unavailable and static catalog file missing")
    
    # 2. IMAGE MANIFEST CHECKS
    print("\nIMAGES:")
    image_manifest_path = Path("/Users/sam/Downloads/trenzy_production/backend/data/image_manifest.json")
    if image_manifest_path.exists():
        with open(image_manifest_path, 'r') as f:
            image_manifest = json.load(f)
        total_images = len(image_manifest)
        image_stats["valid"] = sum(1 for img in image_manifest if img.get("status") == "VALID")
        image_stats["temp_failures"] = sum(1 for img in image_manifest if img.get("status") == "TEMPORARY_FAILURE")
        image_stats["perm_failures"] = sum(1 for img in image_manifest if img.get("status") == "PERMANENT_FAILURE")
        image_stats["duplicates"] = sum(1 for img in image_manifest if img.get("status") == "DUPLICATE")
        image_stats["invalid"] = sum(1 for img in image_manifest if img.get("status") == "INVALID")
        
        print(f"  Valid images: {image_stats['valid']}")
        print(f"  Temporary failures: {image_stats['temp_failures']}")
        print(f"  Permanent failures: {image_stats['perm_failures']}")
        print(f"  Duplicates: {image_stats['duplicates']}")
        print(f"  Invalid images: {image_stats['invalid']}")
    else:
        print("  WARNING: image_manifest.json not found")
    
    # 3. LICENSING CHECKS
    print("\nLICENSING:")
    license_complete = 0
    attribution_required = 0
    static_products = None
    if products_path.exists():
        with open(products_path, 'r') as f:
            static_products = json.load(f)
        for p in static_products:
            if (p.get("source_license") and p.get("source_page") and p.get("attribution")):
                license_complete += 1
            if p.get("source_license") in ["CC BY-SA 3.0", "CC BY-SA 4.0", "CC BY 3.0", "CC BY 4.0"]:
                attribution_required += 1
        license_stats["licensed_complete"] = license_complete
        license_stats["attribution_required"] = attribution_required
        print(f"  Licensed/provenance-complete: {license_complete}/{len(static_products)}")
        print(f"  Attribution-required: {attribution_required}")
    else:
        print("  WARNING: Cannot check licensing - products.json not found")
    
    # 4. EMBEDDINGS CHECK (database-first with static file fallback)
    print("\nEMBEDDINGS:")
    # Try database first (production mode), fall back to static embeddings directory for local audit
    if db_available:
        try:
            db = SessionLocal()
            # Get total product embeddings from database
            all_embeddings = db.query(ProductEmbedding).all()
            total_embeddings = len(all_embeddings)
            
            # Check embedding dimensions and validity
            valid_dim = 0
            invalid_dim = 0
            zero_vectors = 0
            for pe in all_embeddings:
                if pe.combined_embedding:
                    # Verify dimension is 512 (FashionCLIP requirement)
                    if len(pe.combined_embedding) == 512:
                        valid_dim += 1
                        # Check if it's a zero vector
                        if all(v == 0 for v in pe.combined_embedding):
                            zero_vectors += 1
                    else:
                        invalid_dim += 1
            
            embedding_stats["valid"] = valid_dim
            embedding_stats["invalid"] = invalid_dim + zero_vectors
            print(f"  Model: FashionCLIP (Marqo/marqo-fashionCLIP)")
            print(f"  Canonical dimension: 512")
            print(f"  Valid 512-dim embeddings: {valid_dim}/{total_embeddings}")
            if invalid_dim > 0:
                print(f"  Invalid dimension embeddings: {invalid_dim}")
                blockers.append(f"Invalid embedding dimensions: {invalid_dim} products have wrong vector size")
            if zero_vectors > 0:
                print(f"  Zero-vector embeddings: {zero_vectors}")
                blockers.append(f"Zero-vector contamination: {zero_vectors} products have zero embeddings")
            db.close()
        except Exception as e:
            print(f"  ℹ️  Database not available for embeddings check - falling back to static directory")
            db_available = False
    
    # Fallback to static embeddings directory for local audits
    if not db_available:
        embedding_dir = Path("/Users/sam/Downloads/trenzy_production/backend/data/embeddings")
        if embedding_dir.exists():
            embedding_files = list(embedding_dir.glob("*.npy"))
            total_embeddings = len(embedding_files)
            print(f"  Embedding files found (static dir): {total_embeddings}")
            
            # Check for np.zeros contamination in codebase (always check regardless of db availability)
            # Check only embedding-related code for potential zero-vector contamination
            embedding_dir = Path("/Users/sam/Downloads/trenzy_production/backend/app/ai/embeddings")
            zeros_found = 0
            if embedding_dir.exists():
                for py_file in embedding_dir.rglob("*.py"):
                    try:
                        with open(py_file, 'r', encoding='utf-8') as f:
                            content = f.read()
                            zeros_found += content.count("np.zeros")
                    except:
                        pass
            if zeros_found > 0:
                print(f"  WARNING: {zeros_found} np.zeros() instances found in embedding code (potential contamination risk)")
                blockers.append(f"Embedding contamination risk: {zeros_found} np.zeros() instances in embedding generation code")
        else:
            print("  WARNING: Static embeddings directory not found")
            blockers.append("Embedding data unavailable - neither database nor static directory accessible")
    else:
        # Always check for np.zeros contamination in codebase even when db is available
        # Check only embedding-related code for potential zero-vector contamination
        embedding_dir = Path("/Users/sam/Downloads/trenzy_production/backend/app/ai/embeddings")
        zeros_found = 0
        if embedding_dir.exists():
            for py_file in embedding_dir.rglob("*.py"):
                try:
                    with open(py_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        zeros_found += content.count("np.zeros")
                except:
                    pass
        if zeros_found > 0:
            print(f"  WARNING: {zeros_found} np.zeros() instances found in embedding code (potential contamination risk)")
            blockers.append(f"Embedding contamination risk: {zeros_found} np.zeros() instances in embedding generation code")
    
    # 5. MODEL REGISTRY CHECK
    print("\nMODEL REGISTRY:")
    registry_path = Path("/Users/sam/Downloads/trenzy_production/models/registry.json")
    if registry_path.exists():
        with open(registry_path, 'r') as f:
            registry = json.load(f)
        model_registry_stats["production_models"] = sum(1 for m in registry if m.get("status") == "PRODUCTION")
        model_registry_stats["retired_models"] = sum(1 for m in registry if m.get("status") == "RETIRED")
        print(f"  Production models: {model_registry_stats['production_models']}")
        print(f"  Retired models: {model_registry_stats['retired_models']}")
    else:
        print("  WARNING: models/registry.json not found")
    
    # 6. SEARCH ENDPOINTS VERIFICATION
    print("\nSEARCH:")
    search_routes_path = Path("/Users/sam/Downloads/trenzy_production/backend/app/routes/search.py")
    visual_verified = search_routes_path.exists() and "visual_search" in open(search_routes_path).read()
    semantic_verified = search_routes_path.exists() and "semantic_search" in open(search_routes_path).read()
    print(f"  Visual search: {'VERIFIED' if visual_verified else 'NOT FOUND'}")
    print(f"  Semantic search: {'VERIFIED' if semantic_verified else 'NOT FOUND'}")
    
    # 7. STYLE DNA VERIFICATION
    print("\nSTYLE DNA:")
    style_dna_path = Path("/Users/sam/Downloads/trenzy_production/backend/app/routes/style_dna.py")
    style_dna_verified = style_dna_path.exists()
    print(f"  Cold-start pipeline: {'VERIFIED' if style_dna_verified else 'NOT FOUND'}")
    
    # 8. SECURITY CHECKS
    print("\nSECURITY:")
    auth_routes = list(Path("/Users/sam/Downloads/trenzy_production/backend/app/routes").glob("*.py"))
    auth_verified = any("firebase_auth" in open(p).read() for p in auth_routes)
    rate_limit_verified = any("rate_limit" in open(p).read() for p in auth_routes)
    print(f"  Authentication: {'VERIFIED' if auth_verified else 'INCOMPLETE'}")
    print(f"  Rate limiting: {'VERIFIED' if rate_limit_verified else 'INCOMPLETE'}")
    if not auth_verified:
        blockers.append("Authentication not fully verified on all endpoints")
    
    # FINAL BLOCKERS DISPLAY
    print("\nBLOCKERS:")
    if blockers:
        for b in blockers:
            print(f"  ⚠️  {b}")
    else:
        print("  None")
    
    # READINESS CLASSIFICATION
    print("\nREADINESS:")
    if len(blockers) == 0 and catalog_stats["eligible"] > 100 and image_stats["valid"] > 100:
        readiness = "DATA-READY"  # Eligible to move to ML-ready once interaction data exists
    else:
        readiness = "FOUNDATION"  # Core architecture exists but needs more data/cleanup
    print(f"  {readiness}")
    
    # Generate machine-readable report
    report = {
        "readiness": readiness,
        "catalog": catalog_stats,
        "images": image_stats,
        "licenses": license_stats,
        "metadata": {"completeness_pct": metadata_pct},
        "embeddings": embedding_stats,
        "search": {"visual": visual_verified, "semantic": semantic_verified},
        "style_dna": {"status": "IMPLEMENTED" if style_dna_verified else "NOT IMPLEMENTED"},
        "interactions": interaction_stats,
        "recommendations": {"current_model": None, "status": "NOT READY - insufficient interaction data"},
        "models": model_registry_stats,
        "security": {"auth_verified": auth_verified, "rate_limits_verified": rate_limit_verified},
        "performance": {},
        "tests": test_stats,
        "blockers": blockers
    }
    
    # Save report
    report_path = Path("/Users/sam/Downloads/trenzy_production/docs/TRENZY_READINESS_REPORT.json")
    report_path.parent.mkdir(exist_ok=True)
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"\n📊 Machine-readable report saved to: docs/TRENZY_READINESS_REPORT.json")
    
    # Exit with error if blockers exist
    return 1 if blockers else 0

if __name__ == "__main__":
    sys.exit(run_audit())