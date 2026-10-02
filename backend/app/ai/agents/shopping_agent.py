"""AI Shopping Agent.

Handles complex multi-step shopping tasks like:
- "Build me 5 outfits for Goa under ₹8,000"
- "Find a complete wardrobe for college"
- "Shop for a specific event with budget constraints"
"""

from __future__ import annotations

from typing import List, Dict, Optional, Any
import logging
from datetime import datetime

from sqlalchemy.orm import Session

from ...models import Product, User
from ..models_ai import UserStyleProfile
from ..recommendation.rule_based_recommender import RuleBasedRecommender
from ..outfits.outfit_generator import AIOutfitBuilder
from ..personalization.style_dna import StyleDNAExtractor

logger = logging.getLogger(__name__)


class ShoppingAgent:
    """AI Shopping Agent for complex shopping tasks."""

    def __init__(
        self,
        recommender: Optional[RuleBasedRecommender] = None,
        outfit_builder: Optional[AIOutfitBuilder] = None,
        style_extractor: Optional[StyleDNAExtractor] = None,
    ):
        """Initialize shopping agent.

        Args:
            recommender: Hybrid recommender instance
            outfit_builder: Outfit builder instance
            style_extractor: Style DNA extractor
        """
        self.recommender = recommender or RuleBasedRecommender()
        self.outfit_builder = outfit_builder or AIOutfitBuilder()
        self.style_extractor = style_extractor or StyleDNAExtractor()

    def parse_shopping_request(
        self,
        request: str,
    ) -> Dict[str, Any]:
        """Parse natural language shopping request.

        Args:
            request: Natural language request

        Returns:
            Parsed parameters
        """
        request_lower = request.lower()

        params = {
            "destination": None,
            "duration_days": None,
            "budget": None,
            "num_outfits": None,
            "occasion": None,
            "style": None,
            "season": None,
        }

        # Extract destination
        destinations = ["goa", "mumbai", "delhi", "bangalore", "pune", "beach", "mountains", "city"]
        for dest in destinations:
            if dest in request_lower:
                params["destination"] = dest
                break

        # Extract duration
        import re
        duration_match = re.search(r'(\d+)\s*(day|days)', request_lower)
        if duration_match:
            params["duration_days"] = int(duration_match.group(1))

        # Extract budget
        budget_match = re.search(r'₹\s*([\d,]+)|rs\s*([\d,]+)|([\d,]+)\s*rupees', request_lower)
        if budget_match:
            budget_str = budget_match.group(1) or budget_match.group(2) or budget_match.group(3)
            if budget_str:
                params["budget"] = int(budget_str.replace(',', ''))

        # Extract number of outfits
        outfits_match = re.search(r'(\d+)\s*outfit', request_lower)
        if outfits_match:
            params["num_outfits"] = int(outfits_match.group(1))

        # Extract occasion
        occasions = ["casual", "formal", "party", "wedding", "date", "office", "college", "travel"]
        for occ in occasions:
            if occ in request_lower:
                params["occasion"] = occ
                break

        # Extract style
        styles = ["casual", "formal", "streetwear", "boho", "minimal", "classic"]
        for style in styles:
            if style in request_lower:
                params["style"] = style
                break

        # Extract season
        seasons = ["summer", "winter", "monsoon", "spring", "autumn"]
        for season in seasons:
            if season in request_lower:
                params["season"] = season
                break

        return params

    def generate_travel_wardrobe(
        self,
        db: Session,
        user_id: int,
        destination: str,
        duration_days: int,
        budget: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Generate a complete travel wardrobe.

        Args:
            db: Database session
            user_id: User ID
            destination: Travel destination
            duration_days: Number of days
            budget: Optional budget constraint

        Returns:
            Generated wardrobe with outfits and total cost
        """
        # Determine style based on destination
        destination_style_map = {
            "goa": "casual",
            "beach": "casual",
            "city": "casual",
            "mountains": "casual",
        }

        style = destination_style_map.get(destination.lower(), "casual")

        # Number of outfits needed (one per day + extras)
        num_outfits = max(duration_days, 3)

        # Budget per outfit
        budget_per_outfit = None
        if budget:
            budget_per_outfit = budget / num_outfits

        # Generate outfits
        outfits = []
        total_cost = 0

        for i in range(num_outfits):
            context = {
                "style": style,
                "occasion": "casual",
            }

            if budget_per_outfit:
                context["max_price"] = budget_per_outfit

            prompt = f"Day {i+1} outfit for {destination}"

            outfit_options = self.outfit_builder.generate_outfit(
                db=db,
                user_id=user_id,
                prompt=prompt,
                context=context,
                num_options=1,
            )

            if outfit_options:
                option = outfit_options[0]

                # Get product details and calculate cost
                product_ids = [item["product_id"] for item in option["items"]]
                products = db.query(Product).filter(Product.id.in_(product_ids)).all()

                outfit_cost = sum(p.price for p in products)
                total_cost += outfit_cost

                outfits.append({
                    "day": i + 1,
                    "items": [
                        {
                            "id": p.id,
                            "name": p.name,
                            "price": p.price,
                            "image_url": p.image_url,
                            "role": p.outfit_role,
                        }
                        for p in products
                    ],
                    "explanation": option["explanation"],
                    "compatibility_score": option["compatibility_score"],
                    "cost": outfit_cost,
                })

        return {
            "destination": destination,
            "duration_days": duration_days,
            "num_outfits": len(outfits),
            "outfits": outfits,
            "total_cost": total_cost,
            "within_budget": budget is None or total_cost <= budget,
            "budget": budget,
        }

    def generate_event_wardrobe(
        self,
        db: Session,
        user_id: int,
        occasion: str,
        budget: Optional[int] = None,
        num_outfits: int = 3,
    ) -> Dict[str, Any]:
        """Generate wardrobe for a specific event.

        Args:
            db: Database session
            user_id: User ID
            occasion: Event type
            budget: Optional budget
            num_outfits: Number of outfit options

        Returns:
            Generated wardrobe options
        """
        budget_per_outfit = None
        if budget:
            budget_per_outfit = budget / num_outfits

        outfits = []

        for i in range(num_outfits):
            context = {
                "occasion": occasion,
            }

            if budget_per_outfit:
                context["max_price"] = budget_per_outfit

            prompt = f"{occasion} outfit option {i+1}"

            outfit_options = self.outfit_builder.generate_outfit(
                db=db,
                user_id=user_id,
                prompt=prompt,
                context=context,
                num_options=1,
            )

            if outfit_options:
                option = outfit_options[0]

                product_ids = [item["product_id"] for item in option["items"]]
                products = db.query(Product).filter(Product.id.in_(product_ids)).all()

                outfit_cost = sum(p.price for p in products)

                outfits.append({
                    "option": i + 1,
                    "items": [
                        {
                            "id": p.id,
                            "name": p.name,
                            "price": p.price,
                            "image_url": p.image_url,
                            "role": p.outfit_role,
                        }
                        for p in products
                    ],
                    "explanation": option["explanation"],
                    "compatibility_score": option["compatibility_score"],
                    "cost": outfit_cost,
                })

        total_cost = sum(o["cost"] for o in outfits)

        return {
            "occasion": occasion,
            "num_options": len(outfits),
            "outfits": outfits,
            "total_cost": total_cost,
            "within_budget": budget is None or total_cost <= budget,
            "budget": budget,
        }

    def process_shopping_request(
        self,
        db: Session,
        user_id: int,
        request: str,
    ) -> Dict[str, Any]:
        """Process a natural language shopping request.

        Args:
            db: Database session
            user_id: User ID
            request: Natural language request

        Returns:
            Shopping result
        """
        params = self.parse_shopping_request(request)

        # Determine request type
        if params["destination"] and params["duration_days"]:
            # Travel wardrobe request
            result = self.generate_travel_wardrobe(
                db=db,
                user_id=user_id,
                destination=params["destination"],
                duration_days=params["duration_days"],
                budget=params["budget"],
            )
            result["request_type"] = "travel_wardrobe"

        elif params["occasion"]:
            # Event wardrobe request
            result = self.generate_event_wardrobe(
                db=db,
                user_id=user_id,
                occasion=params["occasion"],
                budget=params["budget"],
                num_outfits=params.get("num_outfits", 3),
            )
            result["request_type"] = "event_wardrobe"

        else:
            # Generic request - use recommendations
            context = {}
            if params["style"]:
                context["style"] = params["style"]
            if params["occasion"]:
                context["occasion"] = params["occasion"]
            if params["budget"]:
                context["max_price"] = params["budget"]

            recommendations = self.recommender.recommend(
                db=db,
                user_id=user_id,
                limit=params.get("num_outfits", 10),
                context=context,
            )

            result = {
                "request_type": "recommendations",
                "products": [
                    {
                        "id": p.id,
                        "name": p.name,
                        "price": p.price,
                        "image_url": p.image_url,
                        "score": score,
                    }
                    for p, score in recommendations
                ],
                "total_cost": sum(p.price for p, _ in recommendations),
                "within_budget": params["budget"] is None or sum(p.price for p, _ in recommendations) <= params["budget"],
                "budget": params["budget"],
            }

        result["original_request"] = request
        result["parsed_params"] = params

        return result