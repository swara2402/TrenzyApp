"""Style persona management.

Style personas represent a user's fashion identity (e.g., "Streetwear King",
"Minimalist Queen"). Users can create multiple personas, each with a name,
description, and associated style attributes. The active persona influences
product recommendations and feed filtering.

Persona computation: ``_compute_persona`` builds a persona from a user's
decision history (likes/dislikes). It tallies brand, color, category, and
style frequencies, then generates a name and description from the dominant
attributes.
"""
import hashlib
import logging
import random
from typing import Optional

from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_session
from ..auth_deps import get_current_user
from ..models import StylePersona, UserPreference

logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/persona", tags=["persona"])

_STYLE_PERSONAS = [
    {"name": "Urban Minimalist", "description": "Clean lines, neutral tones, and effortless sophistication. You gravitate toward timeless pieces that speak through simplicity.", "keywords": ["minimal", "clean", "neutral", "timeless", "effortless"], "vibe": "Sophisticated Minimalist", "color_palette": ["#000000", "#FFFFFF", "#808080", "#F5F5F5"]},
    {"name": "Avant-Garde Explorer", "description": "Bold silhouettes, unexpected textures, and fearless experimentation define your fashion DNA.", "keywords": ["bold", "experimental", "unique", "artistic", "edgy"], "vibe": "Creative Disruptor", "color_palette": ["#1A1A2E", "#E94560", "#0F3460", "#16213E"]},
    {"name": "Bohemian Spirit", "description": "Free-flowing fabrics, earthy tones, and artistic expression. Your style tells a story of wanderlust and creativity.", "keywords": ["boho", "earthy", "flowy", "artistic", "free-spirited"], "vibe": "Free Spirit", "color_palette": ["#8B5E3C", "#D4A574", "#F5E6CC", "#4A6741"]},
    {"name": "Streetwear Icon", "description": "Bold logos, oversized fits, and urban edge. You define the cutting edge of casual cool.", "keywords": ["streetwear", "urban", "casual", "bold", "trendy"], "vibe": "Urban Edge", "color_palette": ["#1C1C1C", "#FF4500", "#FFFFFF", "#4169E1"]},
    {"name": "Classic Elegance", "description": "Tailored sophistication, refined fabrics, and timeless grace. You embody understated luxury.", "keywords": ["classic", "elegant", "tailored", "luxury", "refined"], "vibe": "Timeless Grace", "color_palette": ["#2F2F2F", "#C0A080", "#8B7355", "#F5F0EB"]},
    {"name": "Eco-Conscious Curator", "description": "Sustainable materials, ethical choices, and nature-inspired palettes. Your style makes a statement about what matters.", "keywords": ["sustainable", "eco-friendly", "natural", "ethical", "conscious"], "vibe": "Conscious Creator", "color_palette": ["#556B2F", "#8FBC8F", "#F5DEB3", "#2E4053"]},
]


def _uid(token: dict) -> str:
    return token.get("uid") or token.get("user_id") or ""


@router.get("")
async def get_persona(
    user_data: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(user_data)
    persona = session.execute(
        select(StylePersona).where(StylePersona.user_firebase_uid == auth_uid)
    ).scalar_one_or_none()
    if not persona:
        return {"name": "Style Newcomer", "description": "Discover your style identity.", "keywords": [], "vibe": "", "color_palette": []}
    # Look up color_palette from static list since DB doesn't store it
    palette = []
    for sp in _STYLE_PERSONAS:
        if sp["name"] == persona.name:
            palette = sp.get("color_palette", [])
            break
    return {
        "id": persona.id,
        "name": persona.name,
        "description": persona.description,
        "keywords": persona.keywords or [],
        "vibe": persona.vibe or "",
        "color_palette": palette,
    }


def _match_persona_from_preferences(preferences: dict) -> int:
    budget = preferences.get("budget_max")
    categories = preferences.get("preferred_categories", [])

    score = int(hashlib.md5(str(preferences).encode(), usedforsecurity=False).hexdigest(), 16)

    # Budget influences persona selection: higher budgets lean toward luxury/designer personas
    if budget is not None:
        if budget >= 5000:
            score += 1000  # Designer Boutique / Elite Bespoke range
        elif budget >= 1000:
            score += 500   # Modern Classic range
    
    # Map demographic categories to appropriate personas
    # This fixes the category mismatch where onboarding saves demographic categories
    # but the original code was checking for persona names in preferred_categories
    demographic_persona_map = {
        "Men's Fashion": ["Urban Minimalist", "Streetwear Icon", "Classic Elegance"],
        "Women's Fashion": ["Bohemian Spirit", "Classic Elegance", "Avant-Garde Explorer"],
        "Myself": ["Urban Minimalist", "Classic Elegance", "Eco-Conscious Curator"],
        "Gifting": ["Classic Elegance", "Urban Minimalist"],
        "Sustainable Fashion": ["Eco-Conscious Curator"],
        "Streetwear": ["Streetwear Icon", "Avant-Garde Explorer"],
        "Minimalist": ["Urban Minimalist", "Classic Elegance"],
        "Luxury": ["Classic Elegance", "Avant-Garde Explorer"],
        "Casual": ["Urban Minimalist", "Bohemian Spirit"],
        "Formal": ["Classic Elegance"],
    }
    
    # Add scores based on demographic category matches
    for category in categories:
        if category in demographic_persona_map:
            for persona_name in demographic_persona_map[category]:
                for i, sp in enumerate(_STYLE_PERSONAS):
                    if sp["name"] == persona_name:
                        score += (len(_STYLE_PERSONAS) - i) * 10  # Higher score for earlier matches

    return score % len(_STYLE_PERSONAS)


@router.post("/generate")
async def generate_persona(
    preferences: Optional[dict] = None,
    user_data: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(user_data)
    
    try:
        if preferences and preferences.get("preferred_categories"):
            idx = _match_persona_from_preferences(preferences)
        else:
            idx = random.randint(0, len(_STYLE_PERSONAS) - 1)
        
        persona_data = _STYLE_PERSONAS[idx]
        
        existing = session.execute(
            select(StylePersona).where(StylePersona.user_firebase_uid == auth_uid)
        ).scalar_one_or_none()
        
        if existing:
            existing.name = persona_data["name"]
            existing.description = persona_data["description"]
            existing.keywords = persona_data["keywords"]
            existing.vibe = persona_data["vibe"]
            session.commit()
            session.refresh(existing)
            persona = existing
        else:
            persona = StylePersona(
                user_firebase_uid=auth_uid,
                name=persona_data["name"],
                description=persona_data["description"],
                keywords=persona_data["keywords"],
                vibe=persona_data["vibe"],
            )
            session.add(persona)
            session.commit()
            session.refresh(persona)
        
        return {
            "id": persona.id,
            "name": persona.name,
            "description": persona.description,
            "keywords": persona.keywords or [],
            "vibe": persona.vibe or "",
            "color_palette": persona_data.get("color_palette", []),
        }
    except Exception:
        session.rollback()
        logger.exception("Persona generation failed")
        raise HTTPException(status_code=500, detail="Failed to generate persona")


@router.get("/preferences")
async def get_preferences(
    user_data: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(user_data)
    try:
        prefs = session.execute(
            select(UserPreference).where(UserPreference.user_firebase_uid == auth_uid)
        ).scalar_one_or_none()
        if not prefs:
            return {"preferences": None}
        return {
            "preferences": {
                "preferred_categories": prefs.preferred_categories or [],
                "preferred_brands": prefs.preferred_brands or [],
                "preferred_colors": prefs.preferred_colors or [],
                "preferred_seasons": prefs.preferred_seasons or [],
                "preferred_styles": prefs.preferred_styles or [],
                "preferred_aesthetics": prefs.preferred_aesthetics or [],
                "preferred_occasions": prefs.preferred_occasions or [],
                "budget_max": prefs.budget_max,
                "shopping_priorities": prefs.shopping_priorities or [],
                "discover_preferences": prefs.discover_preferences or [],
            }
        }
    except Exception:
        logger.exception("Failed to fetch preferences")
        raise HTTPException(status_code=500, detail="Failed to fetch preferences")


class SavePreferencesRequest(BaseModel):
    preferred_categories: Optional[list[str]] = None
    preferred_brands: Optional[list[str]] = None
    preferred_colors: Optional[list[str]] = None
    preferred_seasons: Optional[list[str]] = None
    preferred_styles: Optional[list[str]] = None
    preferred_aesthetics: Optional[list[str]] = None
    preferred_occasions: Optional[list[str]] = None
    budget_max: Optional[int] = None
    shopping_priorities: Optional[list[str]] = None
    discover_preferences: Optional[list[str]] = None


@router.post("/preferences")
async def save_preferences(
    payload: SavePreferencesRequest,
    user_data: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    auth_uid = _uid(user_data)
    prefs = session.execute(
        select(UserPreference).where(UserPreference.user_firebase_uid == auth_uid)
    ).scalar_one_or_none()
    
    if not prefs:
        prefs = UserPreference(user_firebase_uid=auth_uid)
        session.add(prefs)
    
    if payload.preferred_categories is not None:
        prefs.preferred_categories = payload.preferred_categories
    if payload.preferred_brands is not None:
        prefs.preferred_brands = payload.preferred_brands
    if payload.preferred_colors is not None:
        from ..color_taxonomy import normalize_color
        prefs.preferred_colors = [
            normalize_color(c) or c
            for c in payload.preferred_colors
            if c
        ]
    if payload.preferred_seasons is not None:
        prefs.preferred_seasons = payload.preferred_seasons
    if payload.preferred_styles is not None:
        prefs.preferred_styles = payload.preferred_styles
    if payload.preferred_aesthetics is not None:
        prefs.preferred_aesthetics = payload.preferred_aesthetics
    if payload.preferred_occasions is not None:
        prefs.preferred_occasions = payload.preferred_occasions
    if payload.budget_max is not None:
        prefs.budget_max = payload.budget_max
    if payload.shopping_priorities is not None:
        prefs.shopping_priorities = payload.shopping_priorities
    if payload.discover_preferences is not None:
        prefs.discover_preferences = payload.discover_preferences
    
    session.commit()
    return {"ok": True}


@router.get("/styles")
def get_styles():
    """Return canonical styles for onboarding — fixed clean list, no DB query.

    Uses the style taxonomy so every user sees the same small,
    deduplicated set. Raw catalog variants are mapped at match time.
    """
    from ..style_taxonomy import canonical_styles
    return canonical_styles()

@router.get("/product-types")
def get_product_types():
    """Return canonical categories for onboarding — fixed clean list, no DB query.

    Uses the category taxonomy so every user sees the same small,
    deduplicated set. Raw catalog variants are mapped at match time.
    """
    from ..category_taxonomy import canonical_categories
    return canonical_categories()

@router.get("/colors")
def get_colors():
    """Return canonical colors for onboarding — fixed clean list, no DB query.

    Uses the canonical color taxonomy so every user sees the same small,
    deduplicated set. Raw catalog variants (e.g. "Navy Blue", "Dark Blue")
    are mapped to canonical names via the alias map at match time.
    """
    from ..color_taxonomy import canonical_colors
    return canonical_colors()

@router.get("/discoveries")
def get_discoveries():
    """Return available discovery preferences for onboarding."""
    return ["Trending Now", "New Arrivals", "Sale Picks", "Premium Brands", "Budget Friendly", "Sustainable Fashion", "Celebrity Styles", "Street Style"]

@router.get("/shopping-frequencies")
def get_shopping_frequencies():
    """Return shopping frequency options for onboarding."""
    return ["Daily", "Weekly", "Monthly", "Occasionally", "Only During Sales"]