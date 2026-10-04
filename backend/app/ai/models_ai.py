"""SQLAlchemy ORM models for AI features.

Defines database tables for the AI intelligence layer:
- User style profiles (Style DNA)
- User embeddings
- Product embeddings
- Interaction events (behavioral learning)
- Recommendation events and feedback
- Outfit generations
- AI conversations
- Trend predictions
- Model evaluations
"""

from __future__ import annotations

from typing import Optional
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    JSON,
    func,
    Index,
)
from sqlalchemy.orm import Mapped, mapped_column

from ..db import Base

# Try to import pgvector Vector type, fallback to JSON if not available
# Temporarily force PGVECTOR_AVAILABLE to False to prevent server crash from HNSW index errors
try:
    # Temporarily skip importing pgvector to avoid SQLAlchemy Mapped annotation errors
    # from pgvector.sqlalchemy import Vector
    PGVECTOR_AVAILABLE = False  # Temporarily disabled
    Vector = None  # type: ignore
except ImportError:
    Vector = None  # type: ignore
    PGVECTOR_AVAILABLE = False

# Canonical embedding dimension from central config.
try:
    from .ml_config import EMBEDDING_DIM as _EMBEDDING_DIM
except Exception:
    _EMBEDDING_DIM = 512


class UserStyleProfile(Base):
    """User's learned Style DNA profile.

    Stores extracted style preferences from user interactions and onboarding.
    Combined with FashionCLIP embeddings to generate personalized recommendations.
    
    Supports both:
    1. Initial onboarding preferences (structured style DNA from user choices)
    2. Dynamic profile updates from interaction data
    """

    __tablename__ = "user_style_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False
    )

    # Onboarding source - whether profile was created from onboarding vs interactions
    profile_source: Mapped[str] = mapped_column(String(50), nullable=False, default="interactions")
    # Style category scores (0-1)
    style_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Example: {"streetwear": 0.82, "minimal": 0.71, "classic": 0.34}

    # Color preferences
    color_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Example: {"black": 0.91, "white": 0.84, "pastel": 0.31}

    # Fit preferences
    fit_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Example: {"oversized": 0.77, "relaxed": 0.68, "slim": 0.29}

    # Brand affinity
    brand_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})

    # Category preferences
    category_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})

    # Price sensitivity (0-1, higher = more price-sensitive)
    price_sensitivity: Mapped[float] = mapped_column(Float, nullable=False, default=0.5)

    # Occasion preferences
    occasion_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})

    # Material preferences
    material_scores: Mapped[dict] = mapped_column(JSON, nullable=False, default={})

    # Confidence score (0-1, how confident the model is in this profile)
    confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    # Number of interactions used to build this profile
    interaction_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # pgvector column for the combined style embedding — dimension from ml_config.
    embedding_vector: Mapped[Optional[list]] = mapped_column(
        Vector(_EMBEDDING_DIM) if PGVECTOR_AVAILABLE else JSON,
        nullable=True
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate="now()"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class UserEmbedding(Base):
    """Vector embedding for user preferences.

    Stores the high-dimensional vector representation of a user's fashion preferences.
    Used for similarity search and recommendation scoring.
    """

    __tablename__ = "user_embeddings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False
    )

    # Legacy JSON embedding (for backwards compatibility during migration)
    embedding: Mapped[list] = mapped_column(JSON, nullable=False)
    
    # pgvector column for production vector search — dimension from ml_config.
    embedding_vector: Mapped[Optional[list]] = mapped_column(
        Vector(_EMBEDDING_DIM) if PGVECTOR_AVAILABLE else JSON,
        nullable=True
    )

    # Model version used to generate this embedding
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    # Embedding dimension
    dimension: Mapped[int] = mapped_column(Integer, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


# Add HNSW index for pgvector if available
if PGVECTOR_AVAILABLE:
    Index(
        "idx_user_embeddings_vector",
        UserEmbedding.embedding_vector,
        postgresql_using="hnsw",
        postgresql_with={"m": 16, "ef_construction": 64}
    )


class ProductEmbedding(Base):
    """Vector embedding for products.

    Stores multimodal embeddings (image + text) for each product.
    Enables semantic search and similarity-based recommendations.
    """

    __tablename__ = "product_embeddings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False
    )

    # Legacy JSON embeddings (for backwards compatibility during migration)
    text_embedding: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    image_embedding: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    combined_embedding: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    
    # pgvector column for production vector search — dimension from ml_config.
    combined_embedding_vector: Mapped[Optional[list]] = mapped_column(
        Vector(_EMBEDDING_DIM) if PGVECTOR_AVAILABLE else JSON,
        nullable=True
    )

    # Model version
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    # Embedding dimension
    dimension: Mapped[int] = mapped_column(Integer, nullable=False)

    # Whether this embedding needs regeneration (e.g., product updated)
    needs_regeneration: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate="now()"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


# Add HNSW index for pgvector if available
if PGVECTOR_AVAILABLE:
    Index(
        "idx_product_embeddings_vector",
        ProductEmbedding.combined_embedding_vector,
        postgresql_using="hnsw",
        postgresql_with={"m": 16, "ef_construction": 64}
    )


class InteractionEvent(Base):
    """User interaction events for behavioral learning.

    Tracks all meaningful user actions that serve as signals for the AI system.
    This is the foundation of the behavioral learning pipeline.
    """

    __tablename__ = "interaction_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False
    )

    # Event type
    event_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    # Examples: view_product, like_product, dislike_product, swipe, wishlist,
    # remove_wishlist, search, open_outfit, save_outfit, purchase, blend_vote, share

    # Target entity (if applicable)
    entity_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    # Examples: product, outfit, blend, user

    entity_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)

    # Contextual metadata
    context: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Examples: {"source": "home", "position": 3, "query": "casual dress"}

    # Session identifier (for grouping related events)
    session_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)

    # Timestamp
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True
    )


class RecommendationEvent(Base):
    """Recommendation events and feedback.

    Tracks when recommendations are shown to users and their feedback.
    Used for evaluating and improving recommendation models.
    """

    __tablename__ = "recommendation_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False
    )

    # Recommendation context
    recommendation_type: Mapped[str] = mapped_column(String(50), nullable=False)
    # Examples: home_feed, similar_products, outfit_builder, blend_suggestions

    # Model used
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    # Products recommended (ordered list)
    recommended_products: Mapped[list] = mapped_column(JSON, nullable=False)

    # User feedback
    feedback: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Examples: {"clicked": [1, 3], "liked": [1], "dismissed": [2, 4]}

    # Metrics
    ctr: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # Click-through rate
    conversion_rate: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class OutfitGeneration(Base):
    """AI-generated outfit records.

    Tracks outfits generated by the AI Outfit Builder.
    Stores the generation context and user feedback.
    """

    __tablename__ = "outfit_generations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False
    )

    # Generation prompt/intent
    prompt: Mapped[str] = mapped_column(Text, nullable=False)

    # Generated outfit items
    outfit_items: Mapped[list] = mapped_column(JSON, nullable=False)
    # Example: [{"product_id": 123, "role": "upper"}, {"product_id": 456, "role": "bottom"}]

    # AI explanation
    explanation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Compatibility score (0-1)
    compatibility_score: Mapped[float] = mapped_column(Float, nullable=False)

    # User feedback
    saved: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    modified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # Model version
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class AIConversation(Base):
    """AI Stylist conversation sessions.

    Tracks chat sessions with the AI Fashion Stylist agent.
    """

    __tablename__ = "ai_conversations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False
    )

    # Conversation context
    context: Mapped[dict] = mapped_column(JSON, nullable=False, default={})
    # Example: {"intent": "outfit_suggestion", "occasion": "date"}

    # Number of messages
    message_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Whether this conversation led to a purchase
    led_to_purchase: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate="now()"
    )


class AIMessage(Base):
    """Individual messages in AI conversations."""

    __tablename__ = "ai_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("ai_conversations.id", ondelete="CASCADE"),
        index=True,
        nullable=False
    )

    # Role: user or assistant
    role: Mapped[str] = mapped_column(String(20), nullable=False)

    # Message content
    content: Mapped[str] = mapped_column(Text, nullable=False)

    # Products mentioned/recommended in this message
    mentioned_products: Mapped[list] = mapped_column(JSON, nullable=False, default=[])

    # Whether user accepted the recommendation
    recommendation_accepted: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class TrendPrediction(Base):
    """AI-predicted fashion trends.

    Stores trend predictions from ML models.
    """

    __tablename__ = "trend_predictions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Trend identifier (e.g., product_id, category, style)
    trend_type: Mapped[str] = mapped_column(String(50), nullable=False)
    trend_id: Mapped[int] = mapped_column(Integer, nullable=False)

    # Current trend score (0-1)
    current_score: Mapped[float] = mapped_column(Float, nullable=False)

    # Predicted future score
    predicted_score: Mapped[float] = mapped_column(Float, nullable=False)

    # Momentum (rate of change)
    momentum: Mapped[float] = mapped_column(Float, nullable=False)

    # Prediction horizon (days)
    horizon_days: Mapped[int] = mapped_column(Integer, nullable=False)

    # Confidence in prediction (0-1)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)

    # Model version
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    # When this prediction was made
    prediction_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )

    # Target date for the prediction
    target_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False
    )


class ModelEvaluation(Base):
    """AI model evaluation metrics.

    Tracks performance metrics for different AI models over time.
    Essential for AI credibility and continuous improvement.
    """

    __tablename__ = "model_evaluations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Model identifier
    model_name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    model_version: Mapped[str] = mapped_column(String(50), nullable=False)

    # Evaluation type
    evaluation_type: Mapped[str] = mapped_column(String(50), nullable=False)
    # Examples: recommendation, outfit_generation, stylist, trend_prediction

    # Metrics
    metrics: Mapped[dict] = mapped_column(JSON, nullable=False)
    # Examples for recommendation:
    # {"precision@10": 0.75, "recall@10": 0.62, "ndcg@10": 0.71, "diversity": 0.45}

    # Evaluation period
    evaluation_period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False
    )
    evaluation_period_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False
    )

    # Sample size
    sample_size: Mapped[int] = mapped_column(Integer, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )

    __table_args__ = (
        Index("ix_model_evaluations_evaluation_type", "evaluation_type"),
    )


class ModelVersion(Base):
    """Versioned model registry entry.

    Records every trained model version, its artifact location, metrics, and
    deployment status. The registry uses this to decide what runs in production
    and to audit promotions/demotions over time.
    """

    __tablename__ = "model_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    model_name: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    version: Mapped[str] = mapped_column(String(50), nullable=False)

    # Artifact location on disk (model.<ext> file)
    artifact_path: Mapped[str] = mapped_column(String(500), nullable=False)

    # Model type: lightgbm | xgboost
    model_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Training provenance
    training_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    dataset_version: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    feature_version: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Evaluation metrics, e.g. {"ndcg@10": 0.62, "precision@10": 0.5}
    metrics: Mapped[dict] = mapped_column(JSON, nullable=False, default={})

    # Deployment status: development | staging | production | deprecated | failed
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="development")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )
    promoted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        Index("ix_model_versions_model_name_version", "model_name", "version"),
    )