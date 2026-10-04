"""Blend recommendation and group compatibility algorithms.

This module contains the core business logic for Trenzy's social shopping feature:

**Product ranking** (:func:`compute_blend_results`):
Aggregates swipes from all group members, computes match scores, and ranks
products by total score. Products are grouped by category with tie detection.
The match score is normalized to 0-100% using the formula:

``match_percent = 100 * positive_voters / blend_member_count``

This means a product with all loves scores 100%, all dislikes scores 0%,
and mixed reviews land in between.

**Group compatibility** (:func:`_compute_group_compatibility`):
Computes a "fashion compatibility score" (0-100%) based on Jaccard similarity
of preferences across all member pairs. The score is a weighted combination:

- 30% wardrobe overlap (shared product IDs)
- 30% brand overlap (shared brands)
- 20% category overlap (shared categories)
- 20% color overlap (shared colors)

The Jaccard index (|intersection| / |union|) is used instead of raw counts
because it normalizes for group size — a 2-person group with 5 shared brands
is more compatible than a 10-person group with 5 shared brands.

**Why these weights**: Brand overlap (30%) is weighted highest because brand
loyalty is the strongest fashion signal. Category and color overlap (20% each)
capture style consistency. Wardrobe overlap (30%) captures overall taste similarity.
"""

from __future__ import annotations

import logging

from collections import Counter
from typing import Any

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from .models import BlendMember, BlendSwipe, Product

# ── Invite codes ──────────────────────────────────────────────────────────────
# 6-char uppercase alphanumeric, excluding visually ambiguous characters
# (0/O and 1/I). Length matches the Flutter join screen's fixed 6-box input.
_INVITE_CODE_LENGTH = 6
_INVITE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


def generate_invite_code() -> str:
    """Generate a short random invite code (cryptographically secure)."""
    import secrets

    return "".join(secrets.choice(_INVITE_ALPHABET) for _ in range(_INVITE_CODE_LENGTH))


def get_blend_members(db: Session, blend_id: int | str) -> list[int]:
    """Return the mixi user-ids of a blend's members (ordered by join).

    Used by AI blend endpoints (group preference model).
    """
    from .models import User

    rows = (
        db.query(BlendMember.user_firebase_uid)
        .filter(BlendMember.blend_id == str(blend_id))
        .order_by(BlendMember.joined_at.asc())
        .all()
    )
    uids = [r[0] for r in rows if r[0]]
    if not uids:
        return []
    users = (
        db.query(User.id)
        .filter(User.firebase_uid.in_(uids))
        .all()
    )
    return [r[0] for r in users]


def _product_dict(
    product: Product | None,
    *,
        match_percent = None,
    ) -> dict[str, Any] | None:
    if not product:
        return None
    
    aff_links = product.affiliate_links
    aff_link_str = ""
    if isinstance(aff_links, dict):
        aff_link_str = aff_links.get("default", "") or aff_links.get("link", "") or ""
    elif isinstance(aff_links, str):
        aff_link_str = aff_links

    return {
        "id": product.id,
        "name": product.name,
        "title": product.name,
        "subtitle": product.brand or product.category or "",
        "brand": product.brand,
        "price": product.price or 0,
        "matchScore": round(match_percent) if match_percent is not None else 50,
        "gradient": ["F4F1E8", "E4DBBC"],
        "silhouetteColor": "B2A257",
        "category": product.category,
        "image_url": product.image_url,
        "affiliate_links": aff_link_str,
        "rating": product.rating,
        "tags": product.tags,
    }



def _compute_group_compatibility(db: Session, group_id: str) -> dict[str, Any]:
    """Compute user-to-user fashion compatibility for a group's members.

    Derives shared preferences (brands, categories, colours, styles) from
    each member's wishlist and purchase history, then scores the group.
    """
    members = (
        db.query(BlendMember)
        .filter(BlendMember.blend_id == group_id)
        .all()
    )
    firebase_uids = [m.user_firebase_uid for m in members]
    if len(firebase_uids) < 2:
        return {
            "fashionScore": 0,
            "compatibilityLevel": "N/A",
            "sharedBrands": [],
            "sharedCategories": [],
            "sharedColours": [],
            "sharedStyles": [],
            "wardrobeOverlap": 0,
            "memberProductCounts": {},
        }

    # Batch-fetch all swiped products for all members in a single query
    all_member_products: dict[str, set[str]] = {uid: set() for uid in firebase_uids}
    swipes = db.query(BlendSwipe).filter(
        BlendSwipe.blend_id == group_id,
        BlendSwipe.user_firebase_uid.in_(firebase_uids),
    ).all()
    all_product_ids_set: set[str] = set()
    for swipe in swipes:
        if swipe.product_id:
            all_member_products[swipe.user_firebase_uid].add(swipe.product_id)
            all_product_ids_set.add(swipe.product_id)

    member_data: dict[str, dict[str, set]] = {}
    for uid in firebase_uids:
        member_data[uid] = {
            "wishlist": all_member_products[uid],
            "purchases": all_member_products[uid],
            "all_products": all_member_products[uid],
        }

    all_product_ids: set[str] = set()
    for data in member_data.values():
        all_product_ids.update(data["all_products"])

    products_map: dict[str, Any] = {}
    if all_product_ids:
        for p in db.query(Product).filter(Product.id.in_(list(all_product_ids))).all():
            products_map[p.id] = p

    member_profiles: dict[str, dict[str, Counter]] = {}
    for uid in firebase_uids:
        brands: Counter[str] = Counter()
        categories: Counter[str] = Counter()
        colours: Counter[str] = Counter()
        tags: Counter[str] = Counter()
        for pid in member_data[uid]["all_products"]:
            product = products_map.get(pid)
            if not product:
                continue
            if product.brand:
                brands[product.brand] += 1
            if product.category:
                categories[product.category] += 1
            if product.color:
                colours[product.color] += 1
            for tag in (product.tags or []):
                tags[str(tag)] += 1
        member_profiles[uid] = {
            "brands": brands,
            "categories": categories,
            "colours": colours,
            "tags": tags,
        }

    # ── Compatibility Score ──────────────────────────────────────────────
    #
    # We compute pairwise Jaccard similarity for each attribute across all
    # member pairs. Jaccard = |intersection| / |union|, which normalizes
    # for group size (a 2-person group with 5 shared brands scores higher
    # than a 10-person group with 5 shared brands).
    #
    # The overall fashion score is a weighted average:
    # - 30% wardrobe overlap (shared product IDs) — strongest taste signal
    # - 30% brand overlap — brand loyalty is the most consistent fashion signal
    # - 20% category overlap — whether members shop in the same categories
    # - 20% color overlap — whether members prefer similar colors
    #
    # Why these weights: Brand and wardrobe overlap are the most discriminative
    # signals. Two people who buy the same brands and same products are clearly
    # compatible. Category and color provide secondary signals — you might like
    # different brands but both prefer casual tops in neutral colors.
    #
    # The "compatibility level" label provides a user-friendly interpretation:
    # - 75%+ = "Excellent" (strong taste alignment)
    # - 55-74% = "High" (good overlap with some differences)
    # - 35-54% = "Medium" (moderate overlap, complementary tastes)
    # - <35% = "Low" (very different styles — could be interesting!)

    all_shared_brands: Counter[str] = Counter()
    all_shared_categories: Counter[str] = Counter()
    all_shared_colours: Counter[str] = Counter()
    all_shared_styles: Counter[str] = Counter()

    pair_count = 0
    total_wardrobe_intersection = 0
    total_wardrobe_union = 0
    total_brand_overlap = 0
    total_category_overlap = 0
    total_colour_overlap = 0

    for i in range(len(firebase_uids)):
        for j in range(i + 1, len(firebase_uids)):
            uid_a = firebase_uids[i]
            uid_b = firebase_uids[j]
            pair_count += 1

            set_a = member_data[uid_a]["all_products"]
            set_b = member_data[uid_b]["all_products"]
            intersection = set_a & set_b
            union = set_a | set_b
            total_wardrobe_intersection += len(intersection)
            total_wardrobe_union += len(union)

            brands_a = set(member_profiles[uid_a]["brands"].keys())
            brands_b = set(member_profiles[uid_b]["brands"].keys())
            shared_brands = brands_a & brands_b
            total_brand_overlap += len(shared_brands)
            for b in shared_brands:
                all_shared_brands[b] += 1

            cats_a = set(member_profiles[uid_a]["categories"].keys())
            cats_b = set(member_profiles[uid_b]["categories"].keys())
            shared_cats = cats_a & cats_b
            total_category_overlap += len(shared_cats)
            for c in shared_cats:
                all_shared_categories[c] += 1

            cols_a = set(member_profiles[uid_a]["colours"].keys())
            cols_b = set(member_profiles[uid_b]["colours"].keys())
            shared_cols = cols_a & cols_b
            total_colour_overlap += len(shared_cols)
            for c in shared_cols:
                all_shared_colours[c] += 1

            tags_a = set(member_profiles[uid_a]["tags"].keys())
            tags_b = set(member_profiles[uid_b]["tags"].keys())
            shared_tags = tags_a & tags_b
            for t in shared_tags:
                all_shared_styles[t] += 1

    if pair_count == 0:
        return {
            "fashionScore": 0,
            "compatibilityLevel": "N/A",
            "sharedBrands": [],
            "sharedCategories": [],
            "sharedColours": [],
            "sharedStyles": [],
            "wardrobeOverlap": 0,
        }

    max_brands_possible = max(
        (len(member_profiles[uid]["brands"]) for uid in firebase_uids),
        default=1,
    )
    max_cats_possible = max(
        (len(member_profiles[uid]["categories"]) for uid in firebase_uids),
        default=1,
    )
    max_cols_possible = max(
        (len(member_profiles[uid]["colours"]) for uid in firebase_uids),
        default=1,
    )
    avg_wardrobe_jaccard = (
        total_wardrobe_intersection / total_wardrobe_union
        if total_wardrobe_union > 0
        else 0
    )

    brand_overlap_ratio = min(
        1.0, total_brand_overlap / (pair_count * max_brands_possible)
    ) if max_brands_possible > 0 else 0
    cat_overlap_ratio = min(
        1.0, total_category_overlap / (pair_count * max_cats_possible)
    ) if max_cats_possible > 0 else 0
    colour_overlap_ratio = min(
        1.0, total_colour_overlap / (pair_count * max_cols_possible)
    ) if max_cols_possible > 0 else 0

    fashion_score = round(
        avg_wardrobe_jaccard * 0.30
        + brand_overlap_ratio * 0.30
        + cat_overlap_ratio * 0.20
        + colour_overlap_ratio * 0.20,
        4,
    )
    fashion_percent = min(100, max(0, round(fashion_score * 100)))

    if fashion_percent >= 75:
        level = "Excellent"
    elif fashion_percent >= 55:
        level = "High"
    elif fashion_percent >= 35:
        level = "Medium"
    else:
        level = "Low"

    top_shared_brands = [b for b, _ in all_shared_brands.most_common(10)]
    top_shared_categories = [c for c, _ in all_shared_categories.most_common(10)]
    top_shared_colours = [c for c, _ in all_shared_colours.most_common(8)]
    top_shared_styles = [s for s, _ in all_shared_styles.most_common(8)]

    return {
        "fashionScore": fashion_percent,
        "compatibilityLevel": level,
        "sharedBrands": top_shared_brands,
        "sharedCategories": top_shared_categories,
        "sharedColours": top_shared_colours,
        "sharedStyles": top_shared_styles,
        "wardrobeOverlap": total_wardrobe_intersection,
    }


def compute_blend_results(db: Session, group_id: str) -> dict[str, Any]:
    """Aggregate swipes, rank products, and resolve ties per category."""
    swipes = db.query(BlendSwipe).filter(BlendSwipe.blend_id == group_id).all()

    stats: dict[str, dict[str, Any]] = {}
    for swipe in swipes:
        entry = stats.setdefault(
            swipe.product_id,
            {
                "totalScore": 0,
                "loveCount": 0,
                "likeCount": 0,
                "dislikeCount": 0,
                "voters": set(),
                "positiveVoters": set(),
            },
        )
        entry["totalScore"] += swipe.score
        entry["voters"].add(swipe.user_firebase_uid)
        if swipe.score >= 2:
            entry["loveCount"] += 1
        elif swipe.score == 1:
            entry["likeCount"] += 1
        elif swipe.score < 0:
            entry["dislikeCount"] += 1
        if swipe.score >= 1:
            entry["positiveVoters"].add(swipe.user_firebase_uid)

    # Group consensus = fraction of members who voted IN FAVOR of the product.
    # E.g. both members love it -> 100%; one loves and one disappears -> 50%.
    # This replaces the old formula that let one dominant user's repeated
    # scoring outweigh the rest of the group.
    blend_member_count = (
        db.query(BlendMember).filter(BlendMember.blend_id == group_id).count()
    ) or 1

    ranked: list[dict[str, Any]] = []
    product_ids = list(stats.keys())
    products_map = {
        p.id: p
        for p in db.query(Product).filter(Product.id.in_(product_ids)).all()
    } if product_ids else {}
    for product_id, agg in stats.items():
        product = products_map.get(product_id)
        product_data = _product_dict(product)
        if not product_data:
            continue
        match_percent = 100.0 * len(agg["positiveVoters"]) / blend_member_count

        total_engagement = agg["loveCount"] + agg["likeCount"] + agg["dislikeCount"]
        love_share = (agg["loveCount"] / total_engagement) if total_engagement > 0 else 0.0
        like_share = (agg["likeCount"] / total_engagement) if total_engagement > 0 else 0.0
        dislike_share = (agg["dislikeCount"] / total_engagement) if total_engagement > 0 else 0.0

        product_tags = (product.tags or []) if product else []
        brand = product.brand if product else None
        category = product.category if product else None
        usage = product.usage if product else None
        article_type = product.article_type if product else None

        shared_brands = [brand] if brand else []
        shared_style = []
        if category:
            shared_style.append(category)
        if usage:
            shared_style.append(usage)
        if article_type:
            shared_style.append(article_type)

        overlaps: dict[str, Any] = {
            "tags": list(product_tags)[:6],
            "category": category,
            "brand": brand,
            "usage": usage,
            "article_type": article_type,
            "engagementLevel": (
                "high" if love_share >= 0.5 else ("medium" if like_share >= 0.5 else "mixed")
            ),
        }

        explanation = {
            "topReason":
                "Most loved by your group"
                if love_share >= 0.5
                else ("Strong group like" if like_share >= 0.5 else "Mixed but high score"),
            "sharedBrands": shared_brands,
            "sharedStyle": shared_style,
            "overlaps": overlaps,
            "signals": {
                "loveCount": agg["loveCount"],
                "likeCount": agg["likeCount"],
                "dislikeCount": agg["dislikeCount"],
                "loveShare": round(love_share, 3),
                "likeShare": round(like_share, 3),
                "dislikeShare": round(dislike_share, 3),
                "swipeScore": agg["totalScore"],
            },
        }


        product_data["matchScore"] = int(round(match_percent))
        product_data["explanation"] = explanation

        ranked.append(
            {
                "product": product_data,
                "score": agg["totalScore"],
                "loveCount": agg["loveCount"],
                "likeCount": agg["likeCount"],
                "dislikeCount": agg["dislikeCount"],
            }
        )

    ranked.sort(
        key=lambda item: (
            item["score"],
            item["loveCount"],
            item["likeCount"],
            item["product"].get("matchScore") or 0,
        ),
        reverse=True,
    )

    # Build category buckets dynamically from the actual product categories
    categorized: dict[str, list[dict[str, Any]]] = {}
    for item in ranked:
        cat = item["product"].get("category") or "Uncategorized"
        if cat not in categorized:
            categorized[cat] = []
        categorized[cat].append(
            {
                "product": {
                    "id": item["product"]["id"],
                    "name": item["product"]["name"],
                    "title": item["product"]["title"],
                    "brand": item["product"].get("brand"),
                    "category": item["product"].get("category"),
                    "price": item["product"]["price"],
                    "image_url": item["product"].get("image_url"),
                    "affiliate_links": item["product"].get("affiliate_links"),
                    "rating": item["product"].get("rating"),
                    "gradient": item["product"].get("gradient"),
                    "silhouetteColor": item["product"].get("silhouetteColor"),
                    "matchScore": item["product"].get("matchScore"),
                    "explanation": item["product"].get("explanation"),
                },
                "score": item["score"],
                "loveCount": item["loveCount"],
                "likeCount": item["likeCount"],
            }
        )

    winners: dict[str, Any] = {}
    for cat, items in categorized.items():
        if not items:
            continue
        top_score = items[0]["score"]
        tied = [p for p in items if p["score"] == top_score]
        winners[cat] = {
            "products": tied,
            "isTie": len(tied) > 1,
            "score": top_score,
        }

    overall_winner = ranked[0] if ranked else None
    overall_tied = False
    if ranked:
        top = ranked[0]["score"]
        overall_tied = sum(1 for r in ranked if r["score"] == top) > 1

    compatibility = _compute_group_compatibility(db, group_id)

    return {
        "blendRecommendations": categorized,
        "winners": winners,
        "overallWinner": overall_winner,
        "overallTie": overall_tied,
        "totalSwipes": len(swipes),
        "fashionScore": compatibility["fashionScore"],
        "compatibilityLevel": compatibility["compatibilityLevel"],
        "sharedBrands": compatibility["sharedBrands"],
        "sharedCategories": compatibility["sharedCategories"],
        "sharedColours": compatibility["sharedColours"],
        "sharedStyles": compatibility["sharedStyles"],
        "wardrobeOverlap": compatibility["wardrobeOverlap"],
    }
