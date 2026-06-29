import json
from pathlib import Path

from app.db import SessionLocal
from app.models import Product

db = SessionLocal()

json_path = Path(__file__).parent.parent / "data" / "products.json"

with open(json_path, "r", encoding="utf-8") as f:
    products = json.load(f)

for p in products:
    exists = (
        db.query(Product).filter(Product.id == str(p["id"])).first()
    )

    if exists:
        continue

    db.add(
        Product(
            id=str(p["id"]),
            name=p.get("name"),
            category=p.get("category"),
            subcategory=p.get("subcategory"),
            article_type=p.get("article_type"),
            gender=p.get("gender"),
            color=p.get("color"),
            season=p.get("season"),
            usage=p.get("usage"),
            price=p.get("price"),
            brand=p.get("brand"),
            rating=p.get("rating"),
            image_url=p.get("image_url"),
            tags=p.get("tags"),
            affiliate_links=p.get("affiliate_links"),
        )
    )

db.commit()

logger = logging.getLogger(__name__)
logger.info("Imported %s products", len(products))


