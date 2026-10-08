"""AI feature routes.

API endpoints for AI-powered features:
- AI Recommendations
- Style DNA
- AI Outfit Builder
- AI Fashion Stylist
- Interaction tracking
"""

from __future__ import annotations

from typing import Optional, List, Dict, Any
import logging
import io

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..db import get_session as get_db
from ..auth_deps import get_current_db_user, get_current_user
from ..models import User, Product
from ..ai.models_ai import UserStyleProfile, InteractionEvent
from ..ai.recommendation.rule_based_recommender import RuleBasedRecommender
from ..ai.personalization.event_pipeline import EventPipeline
from ..ai.blends.blend_preference_aggregator import BlendPreferenceAggregator

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

# Initialize ONLY rule-based components required for basic functionality
recommender = RuleBasedRecommender()
group_preference_model = BlendPreferenceAggregator()
event_pipeline = EventPipeline()

# Lazy-loaded ML-powered components (only initialized when first accessed)
# This prevents torch from loading at import time and causing libomp conflicts
_outfit_builder = None
_stylist_agent = None 
_style_extractor = None
_visual_search = None
_trend_predictor = None
_shopping_agent = None

# Property getters to lazy-load ML components only when needed
def get_outfit_builder():
    global _outfit_builder
    if _outfit_builder is None:
        from ..ai.outfits.outfit_generator import AIOutfitBuilder
        _outfit_builder = AIOutfitBuilder()
    return _outfit_builder

def get_stylist_agent():
    global _stylist_agent
    if _stylist_agent is None:
        from ..ai.stylist.fashion_stylist import FashionStylistAgent
        _stylist_agent = FashionStylistAgent()
    return _stylist_agent

def get_style_extractor():
    global _style_extractor
    if _style_extractor is None:
        from ..ai.personalization.style_dna import StyleDNAExtractor
        _style_extractor = StyleDNAExtractor()
    return _style_extractor

def get_visual_search():
    global _visual_search
    if _visual_search is None:
        from ..ai.vision.visual_search import VisualFashionSearch
        _visual_search = VisualFashionSearch()
    return _visual_search

def get_trend_predictor():
    global _trend_predictor
    if _trend_predictor is None:
        from ..ai.trends.trend_ranker import TrendRanker
        _trend_predictor = TrendRanker()
    return _trend_predictor

def get_shopping_agent():
    global _shopping_agent
    if _shopping_agent is None:
        from ..ai.agents.shopping_agent import ShoppingAgent
        _shopping_agent = ShoppingAgent()
    return _shopping_agent

logger.info("AI routes initialized - ML components will lazy-load on first access to avoid libomp conflicts")

# Valid onboarding choices (must match what we present to users)
VALID_AESTHETICS = {"minimal", "streetwear", "classic", "y2k", "boho", "old_money", "sporty", "edgy", "feminine", "casual"}
VALID_COLORS = {"neutrals", "black", "white", "earth_tones", "pastels", "bright_colors", "monochrome"}
VALID_FITS = {"oversized", "relaxed", "regular", "slim", "fitted"}
VALID_OCCASIONS = {"college", "work", "casual", "party", "travel", "date_night", "formal"}
VALID_PREFERENCES = {"prefer_simple_outfits", "prefer_statement_pieces", "prefer_comfort", "prefer_trends", "prefer_timeless"}


# Request/Response Models
class OnboardingRequest(BaseModel):
    """User onboarding request to create initial Style DNA.
    
    Exact preferences from your foundation plan:
    - aesthetic: User's primary style aesthetic
    - colors: Preferred color palettes
    - fit: Preferred garment fit
    - occasion: Primary occasions they shop for
    - preferences: Additional preference flags (comfort, trends, etc.)
    """
    aesthetic: str = Field(..., description="Primary aesthetic choice (minimal, streetwear, classic, y2k, boho, old_money, sporty, edgy, feminine, casual)")
    colors: List[str] = Field(..., description="Preferred color palettes (neutrals, black, white, earth_tones, pastels, bright_colors, monochrome)")
    fit: str = Field(..., description="Preferred fit (oversized, relaxed, regular, slim, fitted)")
    occasion: str = Field(..., description="Primary occasion (college, work, casual, party, travel, date_night, formal)")
    preferences: List[str] = Field(..., description="Additional preferences (prefer_simple_outfits, prefer_statement_pieces, prefer_comfort, prefer_trends, prefer_timeless)")

class OnboardingResponse(BaseModel):
    """Response after successful onboarding."""
    success: bool
    message: str
    style_dna: Dict[str, float]
    user_id: int
    profile_created: bool

class StyleDNAResponse(BaseModel):
    """User Style DNA response."""
    style_scores: Dict[str, float]
    color_scores: Dict[str, float]
    fit_scores: Dict[str, float]
    brand_scores: Dict[str, float]
    category_scores: Dict[str, float]
    occasion_scores: Dict[str, float]
    material_scores: Dict[str, float]
    price_sensitivity: float
    confidence: float
    interaction_count: int
    explanation: str


class RecommendationRequest(BaseModel):
    """Recommendation request."""
    limit: int = Field(default=20, ge=1, le=100)
    context: Optional[Dict[str, Any]] = None
    exclude_product_ids: Optional[List[int]] = None


class RecommendationResponse(BaseModel):
    """Recommendation response."""
    products: List[Dict[str, Any]]
    explanations: List[str]
    model: Optional[str] = None
    model_version: Optional[str] = None
    source: Optional[str] = None


class OutfitRequest(BaseModel):
    """Outfit generation request."""
    prompt: str
    context: Optional[Dict[str, Any]] = None
    num_options: int = Field(default=3, ge=1, le=5)


class OutfitResponse(BaseModel):
    """Outfit generation response."""
    success: bool
    message: Optional[str] = None
    outfits: Optional[List[Dict[str, Any]]] = None
    model: Optional[str] = None
    model_version: Optional[str] = None
    source: Optional[str] = None


class ChatRequest(BaseModel):
    """Chat request."""
    message: str
    conversation_id: Optional[int] = None


class ChatResponse(BaseModel):
    """Chat response."""
    conversation_id: int
    message: str
    mentioned_products: List[Dict[str, Any]]
    model: Optional[str] = None
    model_version: Optional[str] = None


class EventRequest(BaseModel):
    """Interaction event request."""
    event_type: str
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    context: Optional[Dict[str, Any]] = None
    session_id: Optional[str] = None


class VisualSearchResponse(BaseModel):
    """Visual search response."""
    products: List[Dict[str, Any]]
    similarities: List[float]


class BlendInsightsResponse(BaseModel):
    """Blend insights response."""
    member_count: int
    top_styles: List[Dict[str, Any]]
    top_colors: List[Dict[str, Any]]
    style_diversity: float
    group_coherence: float


class BlendPicksResponse(BaseModel):
    """Blend picks response."""
    everyone_picks: List[Dict[str, Any]]
    most_compatible: List[Dict[str, Any]]
    individual_picks: Dict[int, List[Dict[str, Any]]]
    best_compromise: List[Dict[str, Any]]


class TrendResponse(BaseModel):
    """Trend response."""
    products: List[Dict[str, Any]]
    categories: List[Dict[str, Any]]
    styles: List[Dict[str, Any]]
    model: Optional[str] = None
    model_version: Optional[str] = None


class ShoppingRequest(BaseModel):
    """Shopping agent request."""
    request: str


class ShoppingResponse(BaseModel):
    """Shopping agent response."""
    request_type: str
    original_request: str
    parsed_params: Dict[str, Any]
    result: Dict[str, Any]


# Endpoints
@router.get("/models/health")
async def get_models_health(
    current_user: User = Depends(get_current_db_user),
):
    """Get health status of all loaded ML models.

    Returns which models are loaded, their production versions, and any
    degradation (missing artifacts). Services fall back to rule-based baselines
    for models that report ``unavailable``.
    """
    from ..ai.model_manager import ModelManager
    return ModelManager.instance().health()


@router.get("/style-dna", response_model=StyleDNAResponse)
async def get_style_dna(
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get user's Style DNA profile.

    Returns the AI-learned fashion preferences extracted from user interactions.
    """
    profile = db.query(UserStyleProfile).filter(
        UserStyleProfile.user_id == current_user.id
    ).first()

    if not profile:
        # Create initial profile
        profile = get_style_extractor().extract_style_dna(db, current_user.id)
    explanation = get_style_extractor().get_style_explanation(profile)

    return StyleDNAResponse(
        style_scores=profile.style_scores,
        color_scores=profile.color_scores,
        fit_scores=profile.fit_scores,
        brand_scores=profile.brand_scores,
        category_scores=profile.category_scores,
        occasion_scores=profile.occasion_scores,
        material_scores=profile.material_scores,
        price_sensitivity=profile.price_sensitivity,
        confidence=profile.confidence,
        interaction_count=profile.interaction_count,
        explanation=explanation,
    )


@router.post("/style-dna/refresh")
async def refresh_style_dna(
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Force refresh of Style DNA from interaction history."""
    profile = get_style_extractor().extract_style_dna(db, current_user.id)
    return {"message": "Style DNA refreshed", "confidence": profile.confidence}


@router.post("/recommendations", response_model=RecommendationResponse)
async def get_recommendations(
    request: RecommendationRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get AI-powered product recommendations.

    Uses the trained recommendation model (LightGBM) via the ModelManager,
    falling back to rule-based baseline → popularity when no model is loaded.
    Response includes ``model`` / ``model_version`` / ``source`` annotations.
    """
    from ..ai.model_manager import ModelManager
    from ..ai.recommendation.inference import RecommendationInference
    from ..ai.recommendation.model_loader import RecommendationModelLoader

    manager = ModelManager.instance()
    reg = manager.get_model("recommendation")
    if reg is not None:
        # Reuse the startup-preloaded model (never re-unpickle at request time).
        loader = RecommendationModelLoader.from_registered(reg)
        inference = RecommendationInference(model_loader=loader, fallback_to_rules=True)
    else:
        # No model at startup — inference auto-discovers + falls back gracefully.
        inference = RecommendationInference(fallback_to_rules=True)

    products, explanations, model_version, source = inference.get_recommendations(
        db=db,
        user_id=current_user.id,
        limit=request.limit,
        context=request.context,
        exclude_product_ids=request.exclude_product_ids,
    )

    formatted = []
    for product in products:
        formatted.append({
            "id": product.id,
            "name": product.name,
            "price": product.price,
            "image_url": product.image_url,
            "brand": product.brand,
            "category": product.category,
            "style": product.style,
            "color": product.color,
            "fit": product.fit,
        })

    # Track recommendation event
    event_pipeline.track_event(
        db=db,
        user_id=current_user.id,
        event_type="view_recommendations",
        context={"limit": request.limit, "source": source, "model_version": model_version},
    )

    return RecommendationResponse(
        products=formatted,
        explanations=explanations,
        model="recommendation.lightgbm" if source == "ml" else None,
        model_version=model_version,
        source=source,
    )


@router.post("/outfits/generate", response_model=OutfitResponse)
async def generate_outfit(
    request: OutfitRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Generate AI-powered outfit suggestions.

    Uses the AI Outfit Builder with compatibility scoring.
    """
    outfit_options = get_outfit_builder().generate_outfit(
        db=db,
        user_id=current_user.id,
        prompt=request.prompt,
        context=request.context,
        num_options=request.num_options,
    )

    if not outfit_options:
        return OutfitResponse(
            success=False,
            message="Could not generate outfits. Try being more specific.",
        )

    # Get product details for each outfit
    formatted_outfits = []
    for option in outfit_options:
        product_ids = [item["product_id"] for item in option["items"]]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()

        formatted_items = []
        for product in products:
            formatted_items.append({
                "id": product.id,
                "name": product.name,
                "price": product.price,
                "image_url": product.image_url,
                "role": product.outfit_role,
                "color": product.color,
                "style": product.style,
            })

        formatted_outfits.append({
            "items": formatted_items,
            "explanation": option["explanation"],
            "compatibility_score": option["compatibility_score"],
        })

        # Save generation
        get_outfit_builder().save_outfit_generation(
            db=db,
            user_id=current_user.id,
            prompt=request.prompt,
            outfit_option=option,
        )

    return OutfitResponse(
        success=True,
        outfits=formatted_outfits,
    )


@router.post("/stylist/chat", response_model=ChatResponse)
async def stylist_chat(
    request: ChatRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Chat with the AI Fashion Stylist.

    Provides conversational fashion advice with access to:
    - User Style DNA
    - Product catalog
    - Recommendation engine
    - Outfit builder
    """
    response = get_stylist_agent().chat(
        db=db,
        user_id=current_user.id,
        message=request.message,
        conversation_id=request.conversation_id,
    )

    return ChatResponse(
        conversation_id=response["conversation_id"],
        message=response["message"],
        mentioned_products=response["mentioned_products"],
    )


@router.post("/stylist/outfit")
async def stylist_outfit(
    prompt: str = Query(..., description="Outfit request prompt"),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Generate outfit suggestion via AI Stylist."""
    response = get_stylist_agent().generate_outfit_suggestion(
        db=db,
        user_id=current_user.id,
        prompt=prompt,
    )

    return response


@router.post("/events/track")
async def track_event(
    request: EventRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Track a user interaction event for behavioral learning."""
    event = event_pipeline.track_event(
        db=db,
        user_id=current_user.id,
        event_type=request.event_type,
        entity_type=request.entity_type,
        entity_id=request.entity_id,
        context=request.context,
        session_id=request.session_id,
    )

    return {"message": "Event tracked", "event_id": event.id}


@router.get("/events/summary")
async def get_event_summary(
    days: int = Query(default=30, ge=1, le=365),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get summary of user interaction events."""
    summary = event_pipeline.get_user_interaction_summary(
        db=db,
        user_id=current_user.id,
        days=days,
    )

    return summary


@router.post("/events/view-product")
async def track_product_view(
    product_id: int,
    source: str = Query(default="unknown"),
    position: Optional[int] = Query(default=None),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Track product view event."""
    event = event_pipeline.track_product_view(
        db=db,
        user_id=current_user.id,
        product_id=product_id,
        source=source,
        position=position,
    )

    return {"message": "View tracked", "event_id": event.id}


@router.post("/events/like-product")
async def track_product_like(
    product_id: int,
    source: str = Query(default="unknown"),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Track product like event."""
    event = event_pipeline.track_product_like(
        db=db,
        user_id=current_user.id,
        product_id=product_id,
        source=source,
    )

    return {"message": "Like tracked", "event_id": event.id}


@router.post("/visual-search", response_model=VisualSearchResponse)
async def visual_search(
    image: UploadFile = File(...),
    limit: int = Query(default=20, ge=1, le=50),
    min_similarity: float = Query(default=0.5, ge=0.0, le=1.0),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Search for similar products using an uploaded image.

    Uses CLIP vision model to find visually similar fashion items.
    """
    # Validate image file
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    visual_search = get_visual_search()
    
    # Read image bytes
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image file is empty")

    # Vector search requires catalog embeddings generated with the same
    # FashionCLIP model as the uploaded query image.
    from sqlalchemy import func
    from ..models import Product
    embedding_count = (
        db.query(func.count(Product.id))
        .filter(
            Product.image_embedding_vector.isnot(None),
            Product.is_archived.is_(False),
        )
        .scalar()
        or 0
    )
    if embedding_count == 0:
        raise HTTPException(
            status_code=503,
            detail="Visual search is temporarily unavailable while catalog embeddings are being prepared.",
        )

    # Encode image using the canonical FashionCLIP encoder.
    image_embedding = visual_search.encode_image_bytes(image_bytes)

    # Search for similar products
    results = visual_search.search_similar_products(
        db=db,
        image_embedding=image_embedding,
        limit=limit,
        min_similarity=min_similarity,
    )

    # Format results
    products = []
    similarities = []

    for product, similarity in results:
        products.append({
            "id": product.id,
            "name": product.name,
            "price": product.price,
            "image_url": product.image_url,
            "brand": product.brand if product.brand else None,
            "category": product.category if product.category else None,
            "style": product.style,
            "color": product.color,
        })
        similarities.append(similarity)

    # Track visual search event
    event_pipeline.track_event(
        db=db,
        user_id=current_user.id,
        event_type="search",
        context={"search_type": "visual", "result_count": len(results)},
    )

    return VisualSearchResponse(
        products=products,
        similarities=similarities,
    )


@router.post("/onboard", response_model=OnboardingResponse)
async def user_onboarding(
    request: OnboardingRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Create initial Style DNA profile from user onboarding preferences.
    
    Validates onboarding choices, creates/updates UserStyleProfile,
    generates initial style embedding, and tracks the onboarding event.
    """
    # Validate all input choices against our allowed lists
    if request.aesthetic not in VALID_AESTHETICS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid aesthetic. Must be one of: {', '.join(VALID_AESTHETICS)}"
        )
    
    for color in request.colors:
        if color not in VALID_COLORS:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid color palette '{color}'. Must be one of: {', '.join(VALID_COLORS)}"
            )
    
    if request.fit not in VALID_FITS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid fit. Must be one of: {', '.join(VALID_FITS)}"
        )
    
    if request.occasion not in VALID_OCCASIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid occasion. Must be one of: {', '.join(VALID_OCCASIONS)}"
        )
    
    for pref in request.preferences:
        if pref not in VALID_PREFERENCES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid preference '{pref}'. Must be one of: {', '.join(VALID_PREFERENCES)}"
            )
    
    # Check if user already has a style profile
    existing_profile = db.query(UserStyleProfile).filter(
        UserStyleProfile.user_id == current_user.id
    ).first()
    
    # Convert onboarding preferences to Style DNA scores
    style_dna = get_style_extractor().create_initial_profile_from_onboarding(
        aesthetic=request.aesthetic,
        colors=request.colors,
        fit=request.fit,
        occasion=request.occasion,
        preferences=request.preferences
    )
    
    if existing_profile:
        # Update existing profile
        existing_profile.profile_source = "onboarding"
        existing_profile.aesthetic = request.aesthetic
        existing_profile.favorite_colors = request.colors
        existing_profile.preferred_fit = request.fit
        existing_profile.primary_occasion = request.occasion
        existing_profile.additional_preferences = request.preferences
        existing_profile.style_scores = style_dna
        # Generate and store embedding vector if pgvector is available
        from ..ai.vision.fashionclip import get_fashionclip_model
        fashionclip = get_fashionclip_model()
        profile_text = f"{request.aesthetic} {', '.join(request.colors)} {request.fit} {request.occasion} {', '.join(request.preferences)}"
        embedding = fashionclip.encode_text(profile_text)
        existing_profile.embedding_vector = embedding.tolist()
        db.commit()
        profile_created = False
        message = "Existing style profile updated from onboarding preferences"
    else:
        # Create new style profile
        new_profile = UserStyleProfile(
            user_id=current_user.id,
            profile_source="onboarding",
            aesthetic=request.aesthetic,
            favorite_colors=request.colors,
            preferred_fit=request.fit,
            primary_occasion=request.occasion,
            additional_preferences=request.preferences,
            style_scores=style_dna,
        )
        # Generate and store embedding vector if pgvector is available
        from ..ai.vision.fashionclip import get_fashionclip_model
        fashionclip = get_fashionclip_model()
        profile_text = f"{request.aesthetic} {', '.join(request.colors)} {request.fit} {request.occasion} {', '.join(request.preferences)}"
        embedding = fashionclip.encode_text(profile_text)
        new_profile.embedding_vector = embedding.tolist()
        db.add(new_profile)
        db.commit()
        profile_created = True
        message = "New Style DNA profile created successfully from onboarding"
    
    # Track onboarding event
    event_pipeline.track_event(
        db=db,
        user_id=current_user.id,
        event_type="onboarding_completed",
        context={
            "aesthetic": request.aesthetic,
            "colors": request.colors,
            "fit": request.fit,
            "occasion": request.occasion,
            "preferences": request.preferences
        }
    )
    
    return OnboardingResponse(
        success=True,
        message=message,
        style_dna=style_dna,
        user_id=current_user.id,
        profile_created=profile_created
    )


@router.get("/blends/{blend_id}/insights", response_model=BlendInsightsResponse)
async def get_blend_insights(
    blend_id: int,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get AI-powered insights about a blend's group preferences."""
    from ...blend_helpers import get_blend_members

    # Get blend members
    member_ids = get_blend_members(db, blend_id)

    if not member_ids:
        raise HTTPException(status_code=404, detail="Blend not found or has no members")

    # Get insights
    insights = group_preference_model.get_blend_insights(db, member_ids)

    return BlendInsightsResponse(**insights)


@router.get("/blends/{blend_id}/picks", response_model=BlendPicksResponse)
async def get_blend_picks(
    blend_id: int,
    limit: int = Query(default=10, ge=1, le=50),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get AI-powered picks for a blend.

    Returns:
    - Everyone's picks: High group consensus
    - Most compatible: Style-coherent outfit combinations
    - Individual picks: Personalized for each member
    - Best compromise: Balanced for all members
    """
    from ...blend_helpers import get_blend_members

    # Get blend members
    member_ids = get_blend_members(db, blend_id)

    if not member_ids:
        raise HTTPException(status_code=404, detail="Blend not found or has no members")

    # Get different pick types
    everyone_picks = group_preference_model.generate_everyones_picks(
        db, member_ids, limit=limit
    )

    most_compatible = group_preference_model.generate_most_compatible(
        db, member_ids, limit=min(limit // 2, 5)
    )

    individual_picks = group_preference_model.generate_individual_picks(
        db, member_ids, limit_per_member=min(limit // 2, 5)
    )

    best_compromise = group_preference_model.generate_best_compromise(
        db, member_ids, limit=limit
    )

    # Format responses
    def format_product(product, score):
        return {
            "id": product.id,
            "name": product.name,
            "price": product.price,
            "image_url": product.image_url,
            "score": score,
        }

    everyone_formatted = [format_product(p, s) for p, s in everyone_picks]

    compatible_formatted = []
    for items, score in most_compatible:
        compatible_formatted.append({
            "items": [format_product(p, 0) for p in items],
            "compatibility_score": score,
        })

    individual_formatted = {}
    for user_id, picks in individual_picks.items():
        individual_formatted[user_id] = [format_product(p, s) for p, s in picks]

    compromise_formatted = [format_product(p, s) for p, s in best_compromise]

    return BlendPicksResponse(
        everyone_picks=everyone_formatted,
        most_compatible=compatible_formatted,
        individual_picks=individual_formatted,
        best_compromise=compromise_formatted,
    )


@router.get("/trends", response_model=TrendResponse)
async def get_trends(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get AI-predicted fashion trends.

    Returns trending products, categories, and styles.
    """
    trend_predictor = get_trend_predictor()
    # Get trending products
    trending_products = trend_predictor.get_trending_products(
        db=db,
        limit=limit,
        min_score=0.1,
    )

    # Get category trends
    category_trends = trend_predictor.predict_category_trends(
        db=db,
        limit=limit,
    )

    # Get style trends
    style_trends = trend_predictor.predict_style_trends(
        db=db,
        limit=limit,
    )

    # Format responses
    products_formatted = []
    for product, score, momentum in trending_products:
        products_formatted.append({
            "id": product.id,
            "name": product.name,
            "price": product.price,
            "image_url": product.image_url,
            "trend_score": score,
            "momentum": momentum,
        })

    categories_formatted = []
    for category, score, momentum in category_trends:
        categories_formatted.append({
            "name": category,
            "trend_score": score,
            "momentum": momentum,
        })

    styles_formatted = []
    for style, score, momentum in style_trends:
        styles_formatted.append({
            "name": style,
            "trend_score": score,
            "momentum": momentum,
        })

    return TrendResponse(
        products=products_formatted,
        categories=categories_formatted,
        styles=styles_formatted,
    )


@router.get("/trends/product/{product_id}")
async def get_product_trend(
    product_id: int,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Get trend prediction for a specific product."""
    prediction = get_trend_predictor().predict_product_trend(db, product_id)

    if not prediction:
        raise HTTPException(status_code=404, detail="Product not found or no trend data")

    return {
        "product_id": product_id,
        "current_score": prediction.current_score,
        "predicted_score": prediction.predicted_score,
        "momentum": prediction.momentum,
        "horizon_days": prediction.horizon_days,
        "confidence": prediction.confidence,
        "target_date": prediction.target_date.isoformat(),
    }


@router.post("/shopping", response_model=ShoppingResponse)
async def process_shopping_request(
    request: ShoppingRequest,
    current_user: User = Depends(get_current_db_user),
    db: Session = Depends(get_db),
):
    """Process a complex shopping request with the AI Shopping Agent.

    Examples:
    - "Build me 5 outfits for Goa under ₹8,000"
    - "I need outfits for a wedding with a budget of ₹15,000"
    - "Find a casual wardrobe for college"
    """
    result = get_shopping_agent().process_shopping_request(
        db=db,
        user_id=current_user.id,
        request=request.request,
    )

    # Track shopping request event
    event_pipeline.track_event(
        db=db,
        user_id=current_user.id,
        event_type="search",
        context={"search_type": "shopping_agent", "request_type": result["request_type"]},
    )

    return ShoppingResponse(
        request_type=result["request_type"],
        original_request=result["original_request"],
        parsed_params=result["parsed_params"],
        result=result,
    )