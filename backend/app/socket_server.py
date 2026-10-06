"""Socket.IO server for real-time blend and room communication.

Handles bidirectional real-time events for:

- **Blend sessions**: join_blend, blend_swipe, leave_blend — members join a
  Socket.IO room and receive live ``blend_state`` updates after every action.
- **Social rooms**: join_room, send_vote — voting rooms where users vote on
  options and receive live ``vote_updated`` events.
- **Chat**: send_message — messages are persisted and broadcast to the room
  via ``message_created`` events.

**Security**: Every connection MUST present a valid Firebase ID token in the
``auth`` payload. The verified UID is stored in ``_sessions`` and used to
authorize all subsequent events. This prevents user impersonation via
client-supplied userId fields.

**State management**: ``_sessions`` is an in-memory dict mapping Socket.IO
session IDs to user data. Blend/room state is rebuilt from the database on
every action (no cached state), ensuring consistency across server restarts.

**Multi-instance support (Phase 3)**:

Redis enables multi-instance deployment:
  - Socket.IO Redis adapter: Message queue across workers
  - Shared rate limiting: Redis-backed rate limiter (per-sid)
  - Presence tracking: Redis sets for blend presence

When REDIS_URL is set (production), all three use Redis with automatic fallback.
When REDIS_URL is not set (development), in-memory fallback is used.

**Single-worker development without Redis**:

For local development without Docker Compose Redis:
  - Set REDIS_URL="" or omit it (default)
  - In-memory state is used for sessions, rate limiting, and presence
  - Only ONE uvicorn worker should be running
  - If multiple workers are started, they will NOT share state (messages will be lost)
  - This is acceptable for local development and testing

**Multi-instance deployment with Redis**:

For production or multi-worker deployment:
  - Set REDIS_URL=redis://redis:6379/0 (or your Redis endpoint)
  - Socket.IO will automatically use Redis adapter
  - Rate limiting is shared across workers
  - Presence is shared across instances
  - Multiple uvicorn workers will properly coordinate
  - docker-compose.yml includes Redis service by default

**Mock social** (``ENABLE_MOCK_SOCIAL=true``): When enabled, a mock friend
reacts to votes after a 2-second delay. Used for demos and testing.

**Startup**:

The socket server must be initialized at app startup via initialize_socket_server()
to properly wire the Redis adapter if available.
"""

import asyncio
import json
import logging
import os
import random
import time
import datetime
from typing import Optional

import socketio
import redis.asyncio as redis

from .db import SessionLocal
from .models import Blend, BlendMember, BlendSwipe, Room, BlendMessage, BlendInvitation
from .blend_helpers import compute_blend_results
from . import firebase_auth
from .rate_limit import rate_limiter
from .network import get_client_ip_from_environ
from .auth_helpers import (
    require_blend_member_async,
)
from .config import IS_PRODUCTION

logger = logging.getLogger(__name__)

# =============================================================================
# REDIS CONFIGURATION (Phase 3: Multi-instance support)
# =============================================================================
# 
# Redis enables production-grade multi-instance Socket.IO deployment:
#
# 1. Message Queue: Socket.IO Redis adapter broadcasts events to all workers
# 2. Rate Limiting: Shared rate limiter (not per-worker)
# 3. Presence Tracking: Blend presence stored in Redis (not process-local)
#
# When REDIS_URL is set:
#   - All three features use Redis for cross-instance coordination
#   - Multiple uvicorn workers can run safely
#   - Production deployment is supported
#
# When REDIS_URL is NOT set (development):
#   - In-memory fallback is used for all three features
#   - ONLY single-worker mode is supported
#   - Multiple workers will lose state and events (not production-safe)
#   - This is fine for local development and testing
#
# To run production-grade locally:
#   - Start Redis: docker run -d -p 6379:6379 redis:7-alpine
#   - Set REDIS_URL=redis://localhost:6379/0
#   - Then multiple workers can coordinate safely
#
# Or use docker-compose:
#   - docker-compose up
#   - Automatically includes Redis and sets REDIS_URL
# =============================================================================
_redis_url = os.getenv("REDIS_URL", "")
_redis_client: redis.Redis | None = None
_redis_available = False


async def _init_redis() -> tuple[bool, redis.Redis | None]:
    """Initialize Redis connection. Returns (available, client)."""
    global _redis_client, _redis_available
    if not _redis_url:
        if IS_PRODUCTION:
            raise RuntimeError(
                "Refusing to start: REDIS_URL is required in production for multi-instance Socket.IO. "
                "Set REDIS_URL=redis://..."
            )
        logger.info("[Redis] REDIS_URL not set, using in-memory fallback (dev mode only)")
        _redis_available = False
        return False, None
    
    try:
        _redis_client = redis.from_url(
            _redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
        await _redis_client.ping()
        _redis_available = True
        logger.info("[Redis] Connected successfully for multi-instance support")
        return True, _redis_client
    except Exception as e:
        if IS_PRODUCTION:
            raise RuntimeError(
                f"Refusing to start: Failed to connect to Redis in production ({_redis_url}): {e}"
            )
        logger.warning(f"[Redis] Connection failed: {e}. Falling back to in-memory (dev mode)")
        _redis_available = False
        return False, None



# =============================================================================
# RATE LIMITING (shared across workers via Redis)
# =============================================================================
_SOCKET_RATE_LIMIT = 30  # max events per window
_SOCKET_RATE_WINDOW: int = 60  # seconds


async def _check_socket_rate_redis(sid: str) -> bool:
    """Rate limit check using Redis (for multi-instance)."""
    if not _redis_available or not _redis_client:
        return await _check_socket_rate_fallback(sid)
    
    now = time.time()
    key = f"socket_rate:{sid}"
    try:
        # Get current window and clean old entries
        data = await _redis_client.get(key)
        timestamps = json.loads(data) if data else []
        window_start = now - _SOCKET_RATE_WINDOW
        timestamps = [t for t in timestamps if t > window_start]
        
        if len(timestamps) >= _SOCKET_RATE_LIMIT:
            return False
        
        timestamps.append(now)
        await _redis_client.setex(key, _SOCKET_RATE_WINDOW, json.dumps(timestamps))
        return True
    except Exception:
        logger.warning("[Redis] Rate limit check failed, falling back to in-memory")
        return await _check_socket_rate_fallback(sid)


async def _check_socket_rate_fallback(sid: str) -> bool:
    """Fallback rate limit using in-memory (dev only)."""
    now = time.time()
    timestamps = _socket_rate_store.setdefault(sid, [])
    window_start = now - _SOCKET_RATE_WINDOW
    timestamps[:] = [t for t in timestamps if t > window_start]
    if len(timestamps) >= _SOCKET_RATE_LIMIT:
        return False
    timestamps.append(now)
    return True


# In-memory fallback storage for rate limiting
_socket_rate_store: dict[str, list[float]] = {}


# =============================================================================
# CONNECTION-LEVEL RATE LIMITING (per IP, before auth)
# =============================================================================
# Prevents resource exhaustion from unauthenticated connection attempts.
# Uses the centralized rate_limiter from rate_limit.py


def _get_client_ip(environ: dict) -> str:
    """Extract client IP from environ, honoring the trusted-proxy setting."""
    return get_client_ip_from_environ(environ)


# =============================================================================
# PRESENCE TRACKING (shared across workers via Redis, multi-device safe)
# =============================================================================
# Keys: blend_presence:{blend_id} -> set of user_firebase_uid
#       user_sids:{blend_id}:{user_id} -> set of active session IDs (sids)

_blend_presence: dict[str, dict[str, set[str]]] = {}


async def _get_blend_presence_redis(blend_id: str) -> dict[str, list[str]]:
    """Get presence dict from Redis."""
    if not _redis_available or not _redis_client:
        res = {}
        for uid, val in _blend_presence.get(blend_id, {}).items():
            if isinstance(val, set):
                if val:
                    res[uid] = list(val)
            elif isinstance(val, str):
                if val:
                    res[uid] = [val]
        return res
    
    key = f"blend_presence:{blend_id}"
    try:
        members = await _redis_client.smembers(key)
        res: dict[str, list[str]] = {}
        for uid in members:
            uid_str = str(uid)
            sids = await _redis_client.smembers(f"user_sids:{blend_id}:{uid_str}")
            if sids:
                res[uid_str] = [str(s) for s in sids]
        return res
    except Exception:
        logger.warning("[Redis] Failed to get presence from Redis")
        res = {}
        for uid, val in _blend_presence.get(blend_id, {}).items():
            if isinstance(val, set):
                if val:
                    res[uid] = list(val)
            elif isinstance(val, str):
                if val:
                    res[uid] = [val]
        return res


async def _set_blend_presence_redis(blend_id: str, presence: dict[str, set[str]]) -> None:
    """Set presence in Redis."""
    if not _redis_available or not _redis_client:
        _blend_presence[blend_id] = presence
        return
    
    key = f"blend_presence:{blend_id}"
    try:
        await _redis_client.delete(key)
        if presence:
            await _redis_client.sadd(key, *presence.keys())
            for uid, sids in presence.items():
                if sids:
                    await _redis_client.delete(f"user_sids:{blend_id}:{uid}")
                    await _redis_client.sadd(f"user_sids:{blend_id}:{uid}", *sids)
    except Exception:
        logger.warning("[Redis] Failed to set presence in Redis")


async def _add_to_presence_redis(blend_id: str, user_id: str, sid: str) -> None:
    """Add user sid to presence in Redis and in-memory."""
    if blend_id not in _blend_presence:
        _blend_presence[blend_id] = {}
    if user_id not in _blend_presence[blend_id] or not isinstance(_blend_presence[blend_id][user_id], set):
        _blend_presence[blend_id][user_id] = set()
    _blend_presence[blend_id][user_id].add(sid)

    if _redis_available and _redis_client:
        key = f"blend_presence:{blend_id}"
        sid_key = f"user_sids:{blend_id}:{user_id}"
        try:
            await _redis_client.sadd(key, user_id)
            await _redis_client.sadd(sid_key, sid)
        except Exception:
            logger.warning("[Redis] Failed to add to presence")


async def _remove_from_presence_redis(blend_id: str, user_id: str, sid: Optional[str] = None) -> None:
    """Remove user sid (or all sids for user) from presence in Redis and in-memory."""
    if blend_id in _blend_presence and user_id in _blend_presence[blend_id]:
        val = _blend_presence[blend_id][user_id]
        if isinstance(val, set):
            if sid:
                val.discard(sid)
            if not sid or not val:
                _blend_presence[blend_id].pop(user_id, None)
        else:
            if not sid or val == sid:
                _blend_presence[blend_id].pop(user_id, None)
        if not _blend_presence[blend_id]:
            _blend_presence.pop(blend_id, None)

    if _redis_available and _redis_client:
        key = f"blend_presence:{blend_id}"
        sid_key = f"user_sids:{blend_id}:{user_id}"
        try:
            if sid:
                await _redis_client.srem(sid_key, sid)
                remaining = await _redis_client.scard(sid_key)
                if remaining == 0:
                    await _redis_client.srem(key, user_id)
                    await _redis_client.delete(sid_key)
            else:
                await _redis_client.srem(key, user_id)
                await _redis_client.delete(sid_key)
        except Exception:
            logger.warning("[Redis] Failed to remove from presence")


# Configure CORS for sockets — defaults to localhost dev pattern,
# but reads from env in production. MUST use explicit origins (no wildcards).
_socket_origins_env = os.getenv("SOCKET_ALLOWED_ORIGINS", "")
if _socket_origins_env.strip():
    _socket_origins = (
        [o.strip() for o in _socket_origins_env.split(",") if o.strip()]
    )
else:
    if IS_PRODUCTION:
        raise RuntimeError(
            "Refusing to start: SOCKET_ALLOWED_ORIGINS is not set in production. "
            "Set SOCKET_ALLOWED_ORIGINS to a comma-separated list of allowed origins."
        )
    logger.warning(
        "SOCKET_ALLOWED_ORIGINS not set — defaulting to localhost:3000 for development."
    )
    _socket_origins = ["http://localhost:3000", "http://127.0.0.1:3000"]

# Explicitly reject production with wildcard CORS — this is the strictest check
if IS_PRODUCTION:
    if not _socket_origins_env.strip():
        raise RuntimeError(
            "Refusing to start: SOCKET_ALLOWED_ORIGINS is empty in production. "
            "Must specify allowed origins explicitly."
        )
    if any("*" in origin for origin in _socket_origins):
        raise RuntimeError(
            "Refusing to start: SOCKET_ALLOWED_ORIGINS contains wildcard '*' in production. "
            "Set SOCKET_ALLOWED_ORIGINS to specific allowed origins only."
        )

# Socket.IO server configuration (Phase 3: Redis support for multi-instance)
# SECURITY: The single AsyncServer instance is created ONCE here, already
# configured with the validated _socket_origins (wildcards rejected in
# production above). main.py binds this instance into the ASGI app and all
# @sio.event handlers register on it. Never re-create this object after
# import or every registered handler is lost.
#
# The Redis adapter cannot be constructed until the event loop is running,
# so initialize_socket_server() swaps in sio.manager at startup.
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins=_socket_origins,
)


async def initialize_socket_server():
    """Attach the Redis-backed manager to the existing Socket.IO server.

    This must be called before starting the ASGI application, but it must
    NOT re-create ``sio``: event handlers are bound to the original instance
    at import time and main.py's ASGIApp holds a reference to it.
    """
    global sio, _redis_available, _redis_client

    redis_available, redis_client = await _init_redis()
    _redis_available = redis_available
    _redis_client = redis_client

    if redis_available:
        logger.info("[Socket.IO] Using Redis adapter for multi-instance support")
        sio.manager = socketio.AsyncRedisManager(
            url=_redis_url,
            write_only=False,
        )
    else:
        logger.warning("[Socket.IO] No Redis, using in-memory manager (single worker only)")

    return sio

SCORE_MAP = {"like": 1, "love": 2, "dislike": -1}
ENABLE_MOCK_SOCIAL = os.getenv("ENABLE_MOCK_SOCIAL", "false").lower() == "true"
if IS_PRODUCTION and ENABLE_MOCK_SOCIAL:
    raise RuntimeError(
        "Refusing to start: ENABLE_MOCK_SOCIAL is enabled in production. "
        "Mock social behavior is strictly prohibited in production environments."
    )


# sid -> {groupId, userId, userName, kind: room|blend}
_sessions: dict[str, dict] = {}

# blend_id -> {user_firebase_uid: sid, ...} — maps connected users in each blend
# This tracks presence (who is currently online) separate from membership (who is in the blend).
# NOTE: _blend_presence is declared above (line ~224) as dict[str, dict[str, set[str]]]
# with proper typing for multi-sid tracking. No re-declaration needed here.

# Limit maximum concurrent socket sessions to prevent unbounded memory growth.
_MAX_SOCKET_SESSIONS = 10_000
_SESSION_TTL = 3600  # 1 hour


def _cleanup_stale_sessions():
    """Remove sessions older than _SESSION_TTL seconds."""
    now = time.time()
    stale = [sid for sid, data in _sessions.items()
             if now - data.get("connected_at", 0) > _SESSION_TTL]
    for sid in stale:
        _sessions.pop(sid, None)
    if stale:
        logger.info("[Socket] Cleaned up %d stale sessions", len(stale))


async def _get_blend_presence_with_redis(blend_id: str) -> dict[str, list[str]]:
    """Get blend presence — Redis-first, fallback to in-memory.
    
    Returns {user_firebase_uid: [sid, ...], ...} of currently online users in this blend.
    """
    return await _get_blend_presence_redis(blend_id)


async def _build_blend_state(db, group_id: str, last_event: Optional[dict] = None) -> dict:
    """Build the full blend state payload for broadcasting to room members.

    Async function that resolves onlineUserIds from Redis-first (when configured)
    for multi-worker production deployments. Falls back to in-memory presence
    for single-worker development.

    This function is called after every action to rebuild the complete
    state from the database. It includes:
    - Group metadata (name, member count)
    - Member list (userId + userName) — all members in the blend
    - Online users (userIds currently connected) — presence tracking (Redis-first)
    - Blend results computed by ``compute_blend_results`` (recommendations,
      winners, total swipes)
    - The last event that triggered this state update (for UI animation cues)

    Why rebuild from DB on every call: This ensures consistency even if a
    server process crashes mid-action. The database is the source of truth,
    and this function always reflects the current state.
    
    Why async: Presence lookups now use Redis when available for multi-worker
    consistency. Callers must await this function.
    """

    group = db.query(Blend).filter(Blend.id == group_id).first()
    members = db.query(BlendMember).filter(BlendMember.blend_id == group_id).all()
    results = compute_blend_results(db, group_id)
    
    # HARDENING: Get online users from Redis-first (production) or fallback (dev)
    online_member_data = await _get_blend_presence_with_redis(group_id)
    online_user_ids = list(online_member_data.keys())

    return {
        "groupId": group_id,
        "groupName": group.name if group else group_id,
        "memberCount": len(members),
        "members": [
            {"userId": m.user_firebase_uid, "userName": m.user_name} for m in members
        ],
        "onlineUserIds": online_user_ids,  # Presence tracking — who is currently connected (Redis-first)
        "blendRecommendations": results["blendRecommendations"],
        "winners": results["winners"],
        "totalSwipes": results["totalSwipes"],
        "lastEvent": last_event,
    }


@sio.event
async def connect(sid, environ, auth):
    """Socket.IO connect handler — verifies Firebase ID token.

    SECURITY: Previously this accepted any connection without auth, allowing
    user impersonation via the client-supplied `userId` field in subsequent
    events. Now every connection MUST present a valid Firebase ID token in
    the `auth` payload. The verified uid is stored in the session and used
    to authorize all subsequent events.
    
    SECURITY: Connection-level rate limiting per IP prevents resource exhaustion
    from unauthenticated connection attempts before token verification.
    """
    # SECURITY: Rate-limit connections per IP, but ONLY for attempts that fail
    # authentication. Legitimate reconnects (channel flapping, server restarts,
    # mobile network switches) legitimately open numerous fresh connections; a
    # hard per-IP cap on ALL attempts bricked every client after N reconnects in
    # one minute. DoS protection still applies: a spammer must burn a valid
    # Firebase token per attempt (each of which verifies against Firebase first),
    # so unauthenticated floods are still throttled at this gate.
    client_ip = _get_client_ip(environ)
    try:
        return await _authenticate_connection(sid, environ, auth, client_ip)
    except ConnectionRefusedError:
        raise
    except Exception as e:
        logger.exception(
            "[Socket] connect handler crashed for sid=%s client_ip=%s: %s",
            sid,
            client_ip,
            e,
        )
        raise ConnectionRefusedError("Connection refused by server")


async def _authenticate_connection(sid, environ, auth, client_ip):
    # NOTE: Do NOT gate on firebase_auth._firebase_initialized here.
    # verify_token_string() alone decides whether a token is acceptable: it
    # runs the dev-bypass path for signed dev tokens, initializes the Admin
    # SDK lazily when credentials exist, and fails closed in production.
    # Previously this handler pre-refused every connection whenever the Admin
    # SDK had no credentials (common in local dev), silently bricking the
    # socket (chat, swipes, presence) even though the dev bypass was active.
    token = None
    if isinstance(auth, dict):
        token = auth.get("token") or auth.get("idToken")

    if not token:
        if not rate_limiter.is_allowed_connection(client_ip):
            raise ConnectionRefusedError("Too many connection attempts from this IP")
        raise ConnectionRefusedError("Missing auth token in connection payload")

    try:
        decoded = firebase_auth.verify_token_string(token)
    except Exception as e:
        logger.warning(f"[Socket] rejected connection: {e}")
        if not rate_limiter.is_allowed_connection(client_ip):
            raise ConnectionRefusedError("Too many connection attempts from this IP")
        raise ConnectionRefusedError("Invalid auth token")

    _sessions[sid] = {
        "userId": decoded.get("uid") or decoded.get("user_id") or "",
        "userName": decoded.get("name")
        or decoded.get("email", "").split("@")[0]
        or "Guest",
        "groupId": None,
        "kind": None,
        "email": decoded.get("email", ""),
        "connected_at": time.time(),
    }
    if len(_sessions) > _MAX_SOCKET_SESSIONS:
        _cleanup_stale_sessions()
    # SECURITY: Don't log firebase_uid in plain text; use generic identifier
    logger.info("[Socket] Connected: %s", sid)


@sio.event
async def disconnect(sid):
    session = _sessions.pop(sid, None)
    if not session:
        logger.info("[Socket] Disconnected: %s", sid)

        return

    group_id = session.get("groupId")
    user_id = session.get("userId")
    user_name = session.get("userName", "Guest")
    kind = session.get("kind")

    logger.info(
        "[Socket] Disconnected: %s (%s) from %s",
        sid,
        user_name,
        group_id,
    )

    if kind == "blend" and group_id and user_id:
        # P3: Remove from presence tracking (async, uses Redis if available)
        await _remove_from_presence_redis(group_id, user_id, sid)
        
        db = SessionLocal()
        try:
            # P0 FIX: Do NOT delete BlendMember on disconnect.
            # Membership is persistent; only presence is ephemeral.
            # Simply broadcast member_offline event to remaining room members.
            state = await _build_blend_state(
                db,
                group_id,
                last_event={
                    "type": "member_offline",
                    "userId": user_id,
                    "userName": user_name,
                },
            )
            await sio.emit("blend_state", state, room=group_id)
        except Exception:
            logger.exception("[Socket] Error handling blend disconnect")

        finally:
            db.close()

    if kind == "room" and group_id:
        db = SessionLocal()
        try:
            room = db.query(Room).filter(Room.id == group_id).first()
            if room:
                room.participant_count = max((room.participant_count or 1) - 1, 0)
                db.commit()
        except Exception:
            logger.exception("[Socket] Error handling room disconnect")

        finally:
            db.close()


@sio.event
async def refresh_auth(sid, data):
    """Allow client to refresh their auth token mid-session."""
    if not isinstance(data, dict) or not data.get("token"):
        await sio.emit("socket_error", "Missing token in refresh_auth", to=sid)
        return
    try:
        decoded = firebase_auth.verify_token_string(data["token"])
        if sid in _sessions:
            _sessions[sid]["userId"] = decoded.get("uid") or decoded.get("user_id") or _sessions[sid]["userId"]
            _sessions[sid]["userName"] = decoded.get("name") or _sessions[sid].get("userName", "Guest")
            logger.info("[Socket] Refreshed auth for %s", sid)
    except Exception as e:
        logger.warning("[Socket] refresh_auth failed for %s: %s", sid, e)
        await sio.emit("socket_error", "Token refresh failed. Please reconnect.", to=sid)


def _verified_uid(sid: str) -> str | None:
    """Return the verified uid for this sid, or None if not authenticated."""
    return _sessions.get(sid, {}).get("userId")


@sio.event
async def join_room(sid, data):
    """Join a social room, creating it if needed."""
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    room_id = data.get("roomId")
    options = data.get("options")

    if not room_id:
        await sio.emit("socket_error", "Missing roomId", to=sid)
        return

    await sio.enter_room(sid, room_id)
    _sessions[sid].update(
        {
            "groupId": room_id,
            "kind": "room",
        }
    )

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room:
            room = Room(
                id=room_id,
                participant_count=1,
                options=options or [],
                votes={},
            )
            db.add(room)
        else:
            room.participant_count = (room.participant_count or 0) + 1

        db.commit()
        await sio.emit("room_state", room.to_dict(), room=room_id)
    finally:
        db.close()


@sio.event
async def send_vote(sid, data):
    """Record a vote in a social room."""
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    room_id = data.get("roomId")
    option_id = data.get("optionId")
    user_name = _sessions[sid].get("userName", "Guest")

    if not room_id or not option_id:
        await sio.emit("socket_error", "Missing roomId or optionId", to=sid)
        return

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room:
            await sio.emit("socket_error", "Room not found", to=sid)
            return

        new_votes: dict = dict(room.votes or {})
        new_votes[verified_uid] = {
            "optionId": option_id,
            "userName": user_name,
        }
        room.votes = new_votes
        db.commit()

        await sio.emit("vote_updated", room.to_dict(), room=room_id)
    finally:
        db.close()


@sio.event
async def join_blend(sid, data):
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    group_id = data.get("groupId")
    user_name = _sessions[sid].get("userName", "Guest")
    user_id = verified_uid  # VERIFIED — not client-supplied

    # P2: SECURITY NOTE: Client may send userId and userName in the payload.
    # We IGNORE these fields and use the verified uid from the Firebase token instead.
    # This prevents user impersonation. The client should not rely on sending these.

    if not group_id:
        await sio.emit("socket_error", "Missing groupId", to=sid)
        return

    db = SessionLocal()
    try:
        group = db.query(Blend).filter(Blend.id == group_id).first()
        if not group:
            await sio.emit("socket_error", "Blend not found", to=sid)
            return

        # Blend participation is a friends-only safety boundary. Keep the
        # Socket.IO path consistent with the REST join endpoint so clients
        # cannot bypass the relationship check by joining a room directly.
        if group.user_firebase_uid != user_id:
            from .models import Friend

            friendship = db.query(Friend).filter(
                (
                    (Friend.user_firebase_uid == user_id)
                    & (Friend.friend_firebase_uid == group.user_firebase_uid)
                )
                | (
                    (Friend.user_firebase_uid == group.user_firebase_uid)
                    & (Friend.friend_firebase_uid == user_id)
                )
            ).first()
            if not friendship:
                await sio.emit(
                    "socket_error",
                    "Blend participants must be friends with the Blend owner",
                    to=sid,
                )
                return

        # Authorization must complete BEFORE the socket joins the room.\n        # Otherwise an unauthorized client can briefly subscribe to blend\n        # broadcasts even though the request is rejected afterward.\n        await sio.enter_room(sid, group_id)\n        _sessions[sid].update(\n            {\n                "groupId": group_id,\n                "kind": "blend",\n            }\n        )\n\n        existing = (
            db.query(BlendMember)
            .filter(
                BlendMember.blend_id == group_id,
                BlendMember.user_firebase_uid == user_id,
            )
            .first()
        )
        if not existing and group.is_private:
            # P0 FIX: For private blends, only allow join if there is a valid pending/accepted
            # invitation for this exact uid. Remove the empty-string wildcard that allowed
            # unrestricted access via public invite links (which should be enforced at REST API level).
            invited = (
                db.query(BlendInvitation)
                .filter(
                    BlendInvitation.blend_id == group_id,
                    BlendInvitation.invitee_firebase_uid == user_id,
                    BlendInvitation.status.in_(("pending", "accepted")),
                )
                .first()
            )
            if not invited:
                await sio.emit("socket_error", "This blend is private. Join via an invitation link.", to=sid)
                return
            
            # PRODUCT EDGE: Enforce invitation expiry on Socket.IO join
            import datetime
            created_at = invited.created_at
            if created_at is None:
                await sio.emit("socket_error", "Invalid invitation", to=sid)
                return
            
            # Convert SQLAlchemy DateTime to Python datetime for arithmetic
            created_at_dt = created_at.replace(tzinfo=None) if created_at.tzinfo else created_at
            _raw_expires = invited.expires_seconds  # extract to plain Python value
            _expires_sec: int = _raw_expires if isinstance(_raw_expires, int) else 0
            expires_at = created_at_dt + datetime.timedelta(seconds=_expires_sec)
            now_utc = datetime.datetime.now(datetime.timezone.utc)
            if now_utc > expires_at.replace(tzinfo=datetime.timezone.utc):
                invited.status = "expired"
                db.commit()
                await sio.emit("socket_error", "Invitation has expired. Request a new invite.", to=sid)
                return
            
            # PRODUCT EDGE: Check for revocation
            if invited.status == "revoked":
                await sio.emit("socket_error", "This invitation has been revoked.", to=sid)
                return
        if not existing:
            db.add(
                BlendMember(
                    blend_id=group_id,
                    user_firebase_uid=user_id,
                    user_name=user_name,
                )
            )
            db.commit()

        # P2: Update invitation status to 'accepted' when user joins
        # This tracks which invitations have been acted upon
        if not existing and group.is_private:
            # Find any pending/accepted invitation for this user and mark it accepted
            invitation = (
                db.query(BlendInvitation)
                .filter(
                    BlendInvitation.blend_id == group_id,
                    BlendInvitation.invitee_firebase_uid == user_id,
                    BlendInvitation.status.in_(("pending", "accepted")),
                )
                .first()
            )
            if invitation:
                invitation.status = "accepted"
                invitation.accepted_by_firebase_uid = user_id
                invitation.accepted_at = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)  # type: ignore[assignment]
                db.commit()

        # P3: Track presence (async, uses Redis if available)
        await _add_to_presence_redis(group_id, user_id, sid)

        state = await _build_blend_state(
            db,
            group_id,
            last_event={
                "type": "member_joined",
                "userId": user_id,
                "userName": user_name,
            },
        )
        await sio.emit("blend_state", state, room=group_id)
    except Exception:
        logger.exception("[Socket] Error joining blend")
        await sio.emit("socket_error", "Join blend failed. Please try again.", to=sid)
    finally:
        db.close()


@sio.event
async def blend_swipe(sid, data):
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    group_id = data.get("groupId")
    product_id = data.get("productId")
    user_name = _sessions[sid].get("userName", "Guest")
    user_id = verified_uid  # VERIFIED
    swipe_type = (data.get("swipeType") or "like").lower()
    if swipe_type not in SCORE_MAP:
        await sio.emit(
            "socket_error",
            f"Invalid swipe type: {swipe_type}. Must be one of: {', '.join(SCORE_MAP)}",
            to=sid,
        )
        return
    score = SCORE_MAP[swipe_type]

    if not group_id or not product_id:
        await sio.emit("socket_error", "Missing groupId or productId", to=sid)
        return

    # P3: Rate limiting now uses Redis (or fallback to in-memory)
    if not await _check_socket_rate(sid):
        await sio.emit("socket_error", "Too many actions. Please slow down.", to=sid)
        return

    # AUTHORIZATION: Verify user is a member of this blend (prevent IDOR)
    if not await require_blend_member_async(user_id, group_id):
        await sio.emit("socket_error", "Not a member of this blend", to=sid)
        return

    db = SessionLocal()
    try:
        # Upsert the swipe: if user already swiped on this product, update
        # their score (allows changing mind). Otherwise, create new swipe.
        # This means a user can swipe right, then swipe left, and the last
        # swipe wins.
        existing_swipe = (
            db.query(BlendSwipe)
            .filter(
                BlendSwipe.blend_id == group_id,
                BlendSwipe.user_firebase_uid == user_id,
                BlendSwipe.product_id == product_id,
            )
            .first()
        )

        if existing_swipe:
            existing_swipe.score = score
        else:
            db.add(
                BlendSwipe(
                    blend_id=group_id,
                    user_firebase_uid=user_id,
                    product_id=product_id,
                    score=score,
                )
            )
        db.commit()

        # P1 OPTIMIZATION: Emit lightweight swipe_applied event instead of full recompute.
        # This gives immediate UI feedback (next product transition) without the expensive
        # compute_blend_results() call. Full state is rebuilt only on explicit requests
        # (get_blend_state) or at key moments (join, leave).
        swipe_event = {
            "type": "blend_swipe",
            "userId": user_id,
            "userName": user_name,
            "productId": product_id,
            "swipeType": swipe_type,
            "score": score,
        }
        await sio.emit("swipe_applied", swipe_event, room=group_id)
        
        # Also send to the current user for confirmation
        await sio.emit("swipe_confirmed", {"productId": product_id}, to=sid)
    finally:
        db.close()


@sio.event
async def leave_blend(sid, data):
    """User explicitly leaves a blend — deletes BlendMember and broadcasts member_left event.
    
    This is distinct from disconnect(), which only marks presence offline.
    Explicit leave is a user action that removes them from the blend permanently.
    """
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    group_id = data.get("groupId")
    user_name = _sessions[sid].get("userName", "Guest")

    if not group_id:
        await sio.emit("socket_error", "Missing groupId", to=sid)
        return

    db = SessionLocal()
    try:
        # P0 FIX: Explicit leave DOES delete BlendMember (unlike disconnect).
        # This is the user's intentional action to remove themselves from the blend.
        member = (
            db.query(BlendMember)
            .filter(
                BlendMember.blend_id == group_id,
                BlendMember.user_firebase_uid == verified_uid,
            )
            .first()
        )
        if member:
            db.delete(member)

        # P0 FIX ADDITION: leaving also discards the user's votes and any
        # pending invitations they created for this blend, so a departed
        # member can't keep influencing results (mirrors REST leave_group).
        db.query(BlendSwipe).filter(
            BlendSwipe.blend_id == group_id,
            BlendSwipe.user_firebase_uid == verified_uid,
        ).delete()
        db.query(BlendInvitation).filter(
            BlendInvitation.blend_id == group_id,
            BlendInvitation.status == "pending",
            (
                (BlendInvitation.invitee_firebase_uid == verified_uid)
                | (BlendInvitation.inviter_firebase_uid == verified_uid)
            ),
        ).delete()
        db.commit()
        logger.info("[Socket] User %s explicitly left blend %s", verified_uid, group_id)

        # P3: Remove from presence tracking (async, uses Redis if available)
        await _remove_from_presence_redis(group_id, verified_uid)

        # Rebuild state with updated member list (user removed)
        state = await _build_blend_state(
            db,
            group_id,
            last_event={
                "type": "member_left",
                "userId": verified_uid,
                "userName": user_name,
            },
        )
        # Broadcast updated state to remaining members BEFORE leaving the room
        await sio.emit("blend_state", state, room=group_id)
    except Exception:
        logger.exception("[Socket] Error leaving blend")
        await sio.emit("socket_error", "Leave blend failed. Please try again.", to=sid)
    finally:
        db.close()

    # Leave socket room AFTER broadcasting so the departing user gets the update
    await sio.leave_room(sid, group_id)
    _sessions[sid].update({"groupId": None, "kind": None})
    # Confirm to the leaving user
    await sio.emit("blend_left", {"groupId": group_id}, to=sid)


@sio.event
async def get_blend_state(sid, data):
    """Explicitly request the full blend state — used for resync after reconnect.
    
    When a client reconnects (after network loss or app backgrounding), they may have
    missed some events. This event allows them to fetch the current full state without
    having to rejoin the blend. This also triggers a full recompute of blend results,
    ensuring compatibility scores and recommendations are fresh.
    
    P1 OPTIMIZATION: With the new swipe_applied event, most swipes don't trigger full
    recomputes. This event is called explicitly when the client needs the full state
    (e.g., after reconnect, or before showing results screen).
    """
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    group_id = data.get("groupId")
    if not group_id:
        await sio.emit("socket_error", "Missing groupId", to=sid)
        return

    # AUTHORIZATION: Verify user is a member of this blend (prevent IDOR)
    if not await require_blend_member_async(verified_uid, group_id):
        await sio.emit("socket_error", "Not a member of this blend", to=sid)
        return

    db = SessionLocal()
    try:
        # Build and send full state (triggers compute_blend_results for fresh results)
        state = await _build_blend_state(db, group_id)
        await sio.emit("blend_state", state, to=sid)
    except Exception:
        logger.exception("[Socket] Error getting blend state")
        await sio.emit("socket_error", "Failed to fetch blend state. Please try again.", to=sid)
    finally:
        db.close()


_MAX_MESSAGE_LENGTH = 2000
# Simple per-sid rate limiter for socket events
_socket_rate_store: dict[str, list[float]] = {}
_SOCKET_RATE_LIMIT = 30  # max events per window
_SOCKET_RATE_WINDOW = 60  # seconds


async def _check_socket_rate(sid: str) -> bool:
    """Rate limit check (async, uses Redis if available).
    
    This is the primary entry point for rate limiting across all socket events.
    """
    return await _check_socket_rate_redis(sid)


@sio.event
async def send_message(sid, data):
    """Send a chat message to a blend group.
    
    AUTHORIZATION: User must be a member of the blend (prevent IDOR).
    RATE LIMITED: Max message frequency to prevent spam.
    """
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return
    logger.info(
        "[Socket] send_message sid=%s uid=%s groupId=%r",
        sid,
        verified_uid,
        (data or {}).get("groupId"),
    )

    # P3: Rate limiting now uses Redis (or fallback to in-memory)
    if not await _check_socket_rate(sid):
        await sio.emit("socket_error", "Too many messages. Please slow down.", to=sid)
        return

    group_id = data.get("groupId")
    message = (data.get("message") or "").strip()
    user_id = verified_uid  # VERIFIED
    user_name = _sessions[sid].get("userName") or "Guest"
    # Optional product attachment carried through to the persisted message so
    # the REST chat history and the live socket echo stay in sync.
    attached_product_id = data.get("attachedProductId")
    attached_product_title = data.get("attachedProductTitle")
    attached_product_image = data.get("attachedProductImage")
    attached_product_price = data.get("attachedProductPrice")

    if not group_id or not user_id:
        await sio.emit("socket_error", "Missing groupId/userId", to=sid)
        return
    if not message:
        await sio.emit("socket_error", "Message cannot be empty", to=sid)
        return
    if len(message) > _MAX_MESSAGE_LENGTH:
        await sio.emit(
            "socket_error",
            f"Message too long. Maximum {_MAX_MESSAGE_LENGTH} characters.",
            to=sid,
        )
        return

    # AUTHORIZATION: Verify user is a member of this blend (prevent IDOR)
    if not await require_blend_member_async(user_id, group_id):
        await sio.emit("socket_error", "Not a member of this blend", to=sid)
        return

    db = SessionLocal()
    try:
        msg = BlendMessage(
            blend_id=group_id,
            sender_firebase_uid=user_id,
            sender_name=user_name,
            content=message,
            attached_product_id=attached_product_id,
            attached_product_title=attached_product_title,
            attached_product_image=attached_product_image,
            attached_product_price=attached_product_price,
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        payload = {
            "id": msg.id,
            "groupId": group_id,
            "senderId": user_id,
            "senderName": user_name,
            "message": msg.content,
            "createdAt": msg.created_at.isoformat() if msg.created_at and isinstance(msg.created_at, datetime.datetime) else None,
            "attachedProductId": msg.attached_product_id,
            "attachedProductTitle": msg.attached_product_title,
            "attachedProductImage": msg.attached_product_image,
            "attachedProductPrice": msg.attached_product_price,
        }

        await sio.emit("message_created", payload, room=group_id)
    except Exception:
        logger.exception("[Socket] Error sending message")
        await sio.emit("socket_error", "Message failed. Please try again.", to=sid)
    finally:
        db.close()


async def _mock_friend_reaction(room_id: str, voter_name: str) -> None:

    await asyncio.sleep(2.0)

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room or not room.options:
            return

        _options: list = [o for o in (room.options or [])]
        opt_to_vote = random.choice(_options)
        opt_id = opt_to_vote.get("id")

        friends = ["Mia", "Zo", "Ari", "Kai"]
        friend = random.choice([f for f in friends if f.lower() != voter_name.lower()])
        friend_id = f"friend-{friend.lower()}"

        # Use consistent vote structure: {uid: {"optionId": ..., "userName": ...}}
        votes: dict = dict(room.votes or {})
        # Remove friend's previous vote
        for o_id in list(votes.keys()):
            if isinstance(votes[o_id], dict) and votes[o_id].get("userName") == friend:
                del votes[o_id]
                break
        # Add new vote
        votes[friend_id] = {
            "optionId": opt_id,
            "userName": friend,
        }
        room.votes = votes

        reactions: list = [r for r in (room.reactions or [])]
        reactions.append(
            {
                "friendName": friend,
                "emoji": random.choice(["🔥", "💖", "✨", "⭐"]),
                "note": random.choice(
                    ["Love this one!", "Strong pick.", "Easy yes from me."]
                ),
                "optionId": opt_id,
            }
        )
        room.reactions = reactions
        db.commit()

        vote_counts = {
            opt.get("id"): sum(
                1 for v in votes.values()
                if isinstance(v, dict) and v.get("optionId") == opt.get("id")
            )
            for opt in (room.options or [])
            if opt.get("id")
        }
        await sio.emit(
            "vote_updated",
            {
                "voteCounts": vote_counts,
                "reactions": reactions,
                "participantCount": room.participant_count,
                "lastVotedOptionId": opt_id,
            },
            room=room_id,
        )
    except Exception:
        logger.exception("[Socket] Error in mock friend reaction")

    finally:
        db.close()