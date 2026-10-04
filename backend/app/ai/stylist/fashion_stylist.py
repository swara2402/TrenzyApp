"""AI Fashion Stylist agent with RAG.

Provides conversational fashion advice with access to:
- User Style DNA
- Product catalog
- Recommendation engine
- Outfit builder
"""

from __future__ import annotations

from typing import List, Dict, Optional, Any
import logging

from sqlalchemy.orm import Session
from sqlalchemy import func

from ...models import Product, User
from ..models_ai import UserStyleProfile, AIConversation, AIMessage
from ..recommendation.rule_based_recommender import RuleBasedRecommender
from ..outfits.outfit_generator import AIOutfitBuilder
from ..personalization.style_dna import StyleDNAExtractor

logger = logging.getLogger(__name__)


class FashionStylistAgent:
    """AI Fashion Stylist with RAG capabilities."""

    def __init__(self):
        """Initialize the local-only Trenzy stylist.

        The launch contract forbids outbound LLM/API calls for AI features.
        """
        self.recommender = RuleBasedRecommender()
        self.outfit_builder = AIOutfitBuilder()
        self.style_extractor = StyleDNAExtractor()

    def _build_system_prompt(
        self,
        user_style_profile: Optional[UserStyleProfile] = None,
    ) -> str:
        """Build system prompt with user context.

        Args:
            user_style_profile: User's Style DNA

        Returns:
            System prompt string
        """
        base_prompt = """You are Trenzy AI, a fashion stylist assistant for the Trenzy fashion platform.

Your role is to help users with:
- Fashion advice and recommendations
- Outfit suggestions
- Style guidance
- Product recommendations from Trenzy's catalog

You have access to:
- User's Style DNA (their fashion preferences)
- Trenzy's product catalog
- Recommendation engine
- Outfit builder

Be helpful, stylish, and concise. When recommending products, explain WHY they match the user's style.
"""

        if user_style_profile:
            style_info = f"\n\nUser Style DNA:\n"
            style_info += f"- Top styles: {', '.join([s for s, sc in sorted(user_style_profile.style_scores.items(), key=lambda x: x[1], reverse=True)[:3] if sc > 0.3])}\n"
            style_info += f"- Top colors: {', '.join([c for c, sc in sorted(user_style_profile.color_scores.items(), key=lambda x: x[1], reverse=True)[:3] if sc > 0.3])}\n"
            style_info += f"- Top fits: {', '.join([f for f, sc in sorted(user_style_profile.fit_scores.items(), key=lambda x: x[1], reverse=True)[:2] if sc > 0.3])}\n"
            style_info += f"- Confidence: {user_style_profile.confidence:.2f}\n"
            base_prompt += style_info

        return base_prompt

    def _retrieve_relevant_products(
        self,
        db: Session,
        user_id: int,
        query: str,
        limit: int = 5,
    ) -> List[Product]:
        """Retrieve relevant products based on query.

        Args:
            db: Database session
            user_id: User ID
            query: User query
            limit: Number of products to retrieve

        Returns:
            List of relevant products
        """
        # Extract context from query
        context = {}

        query_lower = query.lower()

        # Check for style
        styles = ["casual", "formal", "streetwear", "sporty", "boho", "classic"]
        for style in styles:
            if style in query_lower:
                context["style"] = style
                break

        # Check for occasion
        occasions = ["casual", "formal", "office", "date", "party", "travel"]
        for occasion in occasions:
            if occasion in query_lower:
                context["occasion"] = occasion
                break

        # Get recommendations
        recommendations = self.recommender.recommend(
            db=db,
            user_id=user_id,
            limit=limit,
            context=context,
        )

        return [product for product, score in recommendations]

    def chat(
        self,
        db: Session,
        user_id: int,
        message: str,
        conversation_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Process a chat message from the user.

        Args:
            db: Database session
            user_id: User ID
            message: User message
            conversation_id: Optional conversation ID

        Returns:
            Response with assistant message and any product recommendations
        """
        # Get user style profile
        style_profile = db.query(UserStyleProfile).filter(
            UserStyleProfile.user_id == user_id
        ).first()

        # Get or create conversation
        if conversation_id:
            conversation = db.query(AIConversation).filter(
                AIConversation.id == conversation_id,
                AIConversation.user_id == user_id,
            ).first()
        else:
            conversation = AIConversation(user_id=user_id, context={})
            db.add(conversation)
            db.commit()
            db.refresh(conversation)

        # Save user message
        user_msg = AIMessage(
            conversation_id=conversation.id,
            role="user",
            content=message,
            mentioned_products=[],
        )
        db.add(user_msg)

        # Retrieve relevant products
        relevant_products = self._retrieve_relevant_products(db, user_id, message)

        # Generate a deterministic local response. The launch contract
        # forbids outbound LLM/API calls.
        assistant_message = self._fallback_response(message, relevant_products)

        # Save assistant message
        assistant_msg = AIMessage(
            conversation_id=conversation.id,
            role="assistant",
            content=assistant_message,
            mentioned_products=[p.id for p in relevant_products],
        )
        db.add(assistant_msg)

        # Update conversation
        conversation.message_count += 1
        conversation.updated_at = func.now()

        db.commit()

        return {
            "conversation_id": conversation.id,
            "message": assistant_message,
            "mentioned_products": [
                {
                    "id": p.id,
                    "name": p.name,
                    "price": p.price,
                    "image_url": p.image_url,
                }
                for p in relevant_products[:5]
            ],
        }

    def _fallback_response(
        self,
        message: str,
        relevant_products: List[Product],
    ) -> str:
        """Generate fallback response without LLM.

        Args:
            message: User message
            relevant_products: Relevant products

        Returns:
            Fallback response
        """
        if not relevant_products:
            return "I'd be happy to help with fashion advice! Could you tell me more about what you're looking for?"

        response = f"Based on your style, I found some items that might work for you:\n\n"
        for product in relevant_products[:3]:
            response += f"- {product.name} (₹{product.price})\n"
        response += "\nWould you like more details about any of these?"

        return response

    def generate_outfit_suggestion(
        self,
        db: Session,
        user_id: int,
        prompt: str,
    ) -> Dict[str, Any]:
        """Generate outfit suggestion based on prompt.

        Args:
            db: Database session
            user_id: User ID
            prompt: Outfit request prompt

        Returns:
            Outfit suggestion with explanation
        """
        # Use outfit builder
        outfit_options = self.outfit_builder.generate_outfit(
            db=db,
            user_id=user_id,
            prompt=prompt,
            num_options=1,
        )

        if not outfit_options:
            return {
                "success": False,
                "message": "Couldn't generate an outfit. Try being more specific about the style or occasion.",
            }

        option = outfit_options[0]

        # Get product details
        product_ids = [item["product_id"] for item in option["items"]]
        products = db.query(Product).filter(Product.id.in_(product_ids)).all()

        product_details = []
        for product in products:
            product_details.append({
                "id": product.id,
                "name": product.name,
                "price": product.price,
                "image_url": product.image_url,
                "role": product.outfit_role,
            })

        return {
            "success": True,
            "outfit": product_details,
            "explanation": option["explanation"],
            "compatibility_score": option["compatibility_score"],
        }