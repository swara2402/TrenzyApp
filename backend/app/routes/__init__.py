"""Route package organization and exports.

Routes are organized by feature domain and exposed through this module for
central router registration in main.py.

**Feature Groups**:

- **Authentication & Users**: User creation, login, profile management
  - auth_router: Email/password login, signup, password reset
  - users_router: User profile, preferences
  
- **Social & Friends**: Friend management, social interaction
  - friends_router: Friend list, add/remove friends
  - suggestions_router: Friend and user suggestions
  
- **Products & Catalog**: Product discovery and browsing
  - products_router: List, search, detail products
  - wishlist_router: Save products to wishlist
  
- **Blends & Groups**: Blend creation, membership, real-time features
  - (Socket.IO events handled in socket_server.py)
  
- **Content & Decisions**: User choices and analytics
  - decisions_router: Decision tracking
  - trends_router: Trending products and analytics
  
- **Notifications & Messaging**: Real-time updates and messaging
  - notifications_router: User notifications
  - (Socket.IO chat in socket_server.py)
  
- **Social & Voting**: Social features and voting
  - feed_router: Feed/activity stream
  
- **Payments**: Payment processing and billing
  - payments_router: Payment operations

**Usage in main.py**:
    from .routes import (
        auth_router, users_router, products_router,
        friends_router, trends_router, notifications_router,
        # ... more routers
    )
    
    api = FastAPI()
    api.include_router(auth_router)
    api.include_router(users_router)
    # ... etc
"""

from .auth import router as auth_router
from .decisions import router as decisions_router
from .friends import router as friends_router
from .feed import router as feed_router

from .notifications import router as notifications_router
from .products import router as products_router
from .suggestions import router as suggestions_router
from .trends import router as trends_router
from .users import router as users_router
from .wishlist import router as wishlist_router
from .payments import router as payments_router

# Feature group exports for clarity and organization
__authentication_routes__ = [
    auth_router,
    users_router,
]

__social_routes__ = [
    friends_router,
    suggestions_router,
    feed_router,
]

__catalog_routes__ = [
    products_router,
    wishlist_router,
]

__analytics_routes__ = [
    decisions_router,
    trends_router,
]

__messaging_routes__ = [
    notifications_router,
]

__payments_routes__ = [
    payments_router,
]

# All routers for convenience
__all__ = [
    "auth_router",
    "decisions_router",
    "friends_router",
    "notifications_router",
    "products_router",
    "suggestions_router",
    "trends_router",
    "users_router",
    "wishlist_router",
    "feed_router",
    "payments_router",
    # Feature groups
    "__authentication_routes__",
    "__social_routes__",
    "__catalog_routes__",
    "__analytics_routes__",
    "__messaging_routes__",
    "__payments_routes__",
]
from . import moderation
