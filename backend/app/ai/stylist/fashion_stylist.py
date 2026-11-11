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

from ...models import Product, User, WardrobeItem
from ..models_ai import UserStyleProfile, AIConversation, AIMessage
from ..recommendation.rule_based_recommender import RuleBasedRecommender
from ..outfits.outfit_generator import AIOutfitBuilder
from ..personalization.style_dna import StyleDNAExtractor

logger = logging.getLogger(__name__)


def _selected_wardrobe_ids(message: str) -> set[int]:
    """Read stable item IDs from the authenticated client's styling brief."""
    import re

    match = re.search(
        r"owned wardrobe item ids:\s*([0-9,\s]+)",
        message,
        re.IGNORECASE,
    )
    if not match:
        return set()
    return {int(value) for value in re.findall(r"\d+", match.group(1))}


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

        # Build outfit suggestions from the signed-in user's actual closet.
        # Only selected wardrobe names included by the Flutter style brief are used.
        wardrobe_items = []
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if user and user.firebase_uid and "owned wardrobe pieces" in message.casefold():
                all_items = db.query(WardrobeItem).filter(
                    WardrobeItem.user_firebase_uid == user.firebase_uid
                ).all()
                if "no owned wardrobe pieces are selected" not in message.casefold():
                    selected_ids = _selected_wardrobe_ids(message)
                    if selected_ids:
                        wardrobe_items = [item for item in all_items if item.id in selected_ids]
                    else:
                        # Backward-compatible handling for older app clients.
                        wardrobe_items = [
                            item for item in all_items
                            if item.name and item.name.casefold() in message.casefold()
                        ]
        except Exception as exc:
            logger.warning("Could not load owned wardrobe for stylist: %s", exc)

        # Local deterministic styling remains available without a hosted LLM.
        assistant_message = self._fallback_response(
            message, relevant_products, persona=persona,
            wardrobe_items=wardrobe_items,
        )

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
        wardrobe_items: Optional[List[WardrobeItem]] = None,
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

        user_request = message.split("Styling brief:", 1)[0].casefold()
        outfit_intent = any(
            phrase in user_request
            for phrase in (
                "outfit", "look", "what should i wear", "what do i wear",
                "style me", "dress me", "pair", "match with", "combine",
                "wear with", "put together",
            )
        )

        if wardrobe_items and outfit_intent:
            import re

            def role(item: WardrobeItem) -> str:
                category = (item.category or "").casefold()
                if any(word in category for word in ("dress", "gown", "one-piece", "jumpsuit")):
                    return "dress"
                if any(word in category for word in ("top", "shirt", "tee", "blouse", "upper")):
                    return "top"
                if any(word in category for word in ("trouser", "pant", "jean", "skirt", "short", "bottom")):
                    return "bottom"
                if any(word in category for word in ("shoe", "sneaker", "boot", "sandal", "footwear", "heel", "flat")):
                    return "footwear"
                if any(word in category for word in ("jewel", "accessory", "bag", "belt", "watch", "hat")):
                    return "accessory"
                return "other"

            occasion_match = re.search(r"occasion=([^;.]+)", message, re.IGNORECASE)
            aesthetic_match = re.search(r"aesthetic=([^;.]+)", message, re.IGNORECASE)
            occasion = occasion_match.group(1).strip() if occasion_match else "your occasion"
            aesthetic = aesthetic_match.group(1).strip() if aesthetic_match else persona
            palettes = {
                "minimal": ("black", "white", "grey", "gray", "beige", "cream", "navy", "brown"),
                "streetwear": ("black", "white", "grey", "gray", "denim", "blue", "red", "green"),
                "classic": ("navy", "white", "black", "beige", "brown", "cream"),
                "old money": ("navy", "white", "beige", "cream", "brown", "black"),
                "boho": ("earth", "rust", "olive", "beige", "brown", "tan"),
                "y2k": ("pink", "silver", "blue", "purple", "denim"),
                "sporty": ("black", "white", "grey", "gray", "blue", "red"),
            }
            palette = palettes.get(aesthetic.casefold(), ())

            def best(items: List[WardrobeItem]) -> Optional[WardrobeItem]:
                if not items:
                    return None
                return max(
                    items,
                    key=lambda item: (
                        int(bool(palette) and any(
                            token in (item.color or "").casefold() for token in palette
                        )),
                        int(bool(item.is_favorite)),
                        -int(item.id or 0),
                    ),
                )

            by_role = {
                key: [item for item in wardrobe_items if role(item) == key]
                for key in ("dress", "top", "bottom", "footwear", "accessory")
            }
            chosen = []
            dress = best(by_role["dress"])
            if dress:
                chosen.append(dress)
            else:
                top = best(by_role["top"])
                bottom = best(by_role["bottom"])
                if top:
                    chosen.append(top)
                if bottom:
                    chosen.append(bottom)
            footwear = best(by_role["footwear"])
            accessory = best(by_role["accessory"])
            if footwear:
                chosen.append(footwear)
            if accessory:
                chosen.append(accessory)

            if chosen:
                lines = [f"Here's a {aesthetic} look for {occasion}, built from pieces you own:"]
                for item in chosen:
                    detail = f" ({item.color})" if item.color else ""
                    lines.append(f"• {item.name}{detail}")
                colors = [item.color.strip() for item in chosen if item.color and item.color.strip()]
                if len(colors) >= 2:
                    lines.append("\nThese colours work together as your base; keep any extra accessories simple so the look feels balanced.")
                if not dress and not by_role["top"]:
                    lines.append("\\nWardrobe gap: add a top to complete the outfit.")
                if not dress and not by_role["bottom"]:
                    lines.append("\\nWardrobe gap: add a bottom to complete the outfit.")
                if not footwear:
                    lines.append("\\nWardrobe gap: add a footwear option to finish the look.")
                if not accessory:
                    lines.append("\\nOptional finishing touch: add jewellery or a bag from your closet.")
                return "\n".join(lines)
            return (
                f"I found {len(wardrobe_items)} selected piece(s) in your closet, but their categories "
                "aren't specific enough to build an outfit yet. Label them as tops, bottoms, dresses, "
                "footwear, or accessories and I'll combine the actual pieces."
            )

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