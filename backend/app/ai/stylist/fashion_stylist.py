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
        base_prompt = """You are Trenzy's AI Fashion Stylist, a friendly, inclusive, and knowledgeable fashion expert for the Trenzy fashion platform.

Your role is to help users with:
- Outfit combinations and suggestions for any occasion
- Color coordination and palette advice
- Personal style development and refinement
- Wardrobe organization and staple piece recommendations
- Budget-conscious fashion choices
- Seasonal styling tips
- Accessible and inclusive fashion advice for all body types, styles, and budgets

Always be:
- Friendly, warm, and approachable in your tone
- Concise but comprehensive - keep responses focused and useful
- Inclusive and respectful of all personal styles
- Ask clarifying questions when the user's request is too vague
- Never claim to see the user's wardrobe or profile unless that data is actually provided to you
- Never make up product information or prices
- Focus on practical, actionable fashion advice that the user can implement

If you don't know something, be honest and ask for more details to better assist them.
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
        persona: str = "everyday",
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
        # Retrieve relevant products
        relevant_products = self._retrieve_relevant_products(db, user_id, message)

        # Use the local catalog-backed response path for reliable beta replies.
        # Remote model calls can stall when an optional provider is unavailable;
        # the launch configuration requires the stylist to work without them.
        assistant_message = self._fallback_response(message, relevant_products, persona=persona)

        # Save assistant message
        assistant_msg = AIMessage(
            conversation_id=conversation.id,
            role="assistant",
            content=assistant_message,
            mentioned_products=[p.id for p in relevant_products],
        )
        db.add(assistant_msg)

        # Update conversation
        # One user message and one assistant message were persisted.
        conversation.message_count = (conversation.message_count or 0) + 2
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

    def _generate_ollama_llm_response(
        self,
        system_prompt: str,
        user_message: str,
    ) -> Optional[str]:
        """Generate LLM response using Ollama API."""
        from ...app.config import OLLAMA_BASE_URL, OLLAMA_MODEL, OLLAMA_API_KEY
        import requests
        
        if not OLLAMA_BASE_URL:
            return None
            
        try:
            url = f"{OLLAMA_BASE_URL.rstrip('/')}/api/chat"
            headers = {
                "Content-Type": "application/json",
            }
            if OLLAMA_API_KEY:
                headers["Authorization"] = f"Bearer {OLLAMA_API_KEY}"
                
            payload = {
                "model": OLLAMA_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                "stream": False,
                "options": {
                    "num_predict": 250,
                    "temperature": 0.7,
                }
            }
            logger.info(f"Calling Ollama API at {url} with model {OLLAMA_MODEL}")
            resp = requests.post(url, headers=headers, json=payload, timeout=30)
            if resp.status_code == 200:
                data = resp.json()
                if "message" in data and "content" in data["message"]:
                    return data["message"]["content"].strip()
            else:
                logger.warning(f"Ollama API returned status code {resp.status_code}: {resp.text}")
        except Exception as err:
            logger.warning(f"Ollama API call failed: {err}")
        return None

    def _generate_hf_llm_response(
        self,
        system_prompt: str,
        user_message: str,
    ) -> Optional[str]:
        """Generate LLM response using Hugging Face Free Serverless Inference API."""
        import os
        import requests
        hf_token = (
            os.getenv("HF_TOKEN")
            or os.getenv("HUGGINGFACE_API_KEY")
            or os.getenv("HF_API_KEY")
        )
        if not hf_token:
            return None
        try:
            url = "https://router.huggingface.co/hf-inference/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {hf_token}",
                "Content-Type": "application/json",
            }
            payload = {
                "model": "meta-llama/Llama-3.2-1B-Instruct",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                "max_tokens": 250,
                "temperature": 0.7,
            }
            resp = requests.post(url, headers=headers, json=payload, timeout=6)
            if resp.status_code == 200:
                data = resp.json()
                choices = data.get("choices", [])
                if choices and "message" in choices[0]:
                    return choices[0]["message"]["content"].strip()
        except Exception as err:
            logger.warning(f"HF Inference API call failed: {err}")
        return None

    def _fallback_response(
        self,
        message: str,
        relevant_products: List[Product],
        persona: str = "everyday",
    ) -> str:
        """Generate friendly fashion response based on query and catalog.

        Args:
            message: User message
            relevant_products: Relevant products

        Returns:
            Fashion advice response
        """
        persona_styles = {
            "everyday": ("Your friendly everyday stylist", "balanced, wearable outfits"),
            "minimalist": ("Your clean-girl minimalist stylist", "clean lines, versatile basics, and neutral palettes"),
            "streetwear": ("Your streetwear stylist", "relaxed fits, sneaker-led looks, and statement layers"),
            "trendsetter": ("Your trend-forward stylist", "fresh silhouettes, playful details, and standout pieces"),
        }
        persona_name, persona_focus = persona_styles.get(persona, persona_styles["everyday"])
        msg_lower = message.strip().lower()

        # Handle casual greetings warmly
        greetings = ["hey", "heyyy", "heyy", "hi", "hello", "hola", "yo", "sup", "good morning", "good evening"]
        if any(msg_lower == g for g in greetings) or msg_lower.startswith("hey") or msg_lower.startswith("hi"):
            return f"Hey there! I'm {persona_name}. I focus on {persona_focus}. Tell me the occasion and I'll help you put a look together. 💗"

        if not relevant_products:
            return f"I'd love to help you style '{message}' with {persona_focus}. Try adding the occasion, colours, or budget and I'll narrow it down for you."

        response = f"As {persona_name}, I'd style '{message}' around {persona_focus}. Here are some catalog picks:\n\n"
        for product in relevant_products[:3]:
            response += f"• {product.name} — ₹{product.price:.0f}\n"
        response += "\nLet me know if you'd like outfit combinations with these!"

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