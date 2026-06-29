import asyncio
import os
import random
import logging

import socketio

from .blend_helpers import compute_blend_results
from .db import SessionLocal
from .models import Room, Group, GroupMember, GroupSwipe, GroupMessage
from .firebase_auth import verify_token_string, _firebase_initialized, init_firebase_admin

logger = logging.getLogger(__name__)

# Configure CORS for sockets — defaults to dev '*' for local testing,
# but reads from env in production.
_socket_origins_env = os.getenv("SOCKET_ALLOWED_ORIGINS", "*")
_socket_origins = (
    [o.strip() for o in _socket_origins_env.split(",") if o.strip()]
    if _socket_origins_env.strip()
    else "*"
)

sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins=_socket_origins)

SCORE_MAP = {"like": 1, "love": 2, "dislike": -1}
ENABLE_MOCK_SOCIAL = os.getenv("ENABLE_MOCK_SOCIAL", "false").lower() == "true"

# sid -> {groupId, userId, userName, kind: room|blend}
_sessions: dict[str, dict] = {}


from typing import Optional


def _build_blend_state(db, group_id: str, last_event: Optional[dict] = None) -> dict:

    group = db.query(Group).filter(Group.id == group_id).first()
    members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
    results = compute_blend_results(db, group_id)

    return {
        "groupId": group_id,
        "groupName": group.name if group else group_id,
        "memberCount": len(members),
        "members": [
            {"userId": m.user_firebase_uid, "userName": m.user_name}
            for m in members
        ],
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
    """
    if not _firebase_initialized:
        init_firebase_admin()
    if not _firebase_initialized:
        # Fail closed — refuse connection if auth backend is down.
        raise ConnectionRefusedError("Authentication backend unavailable")

    token = None
    if isinstance(auth, dict):
        token = auth.get("token") or auth.get("idToken")
    if not token:
        # Some clients pass it as a query param instead.
        qs = environ.get("QUERY_STRING", "")
        for pair in qs.split("&"):
            if pair.startswith("token=") or pair.startswith("idToken="):
                token = pair.split("=", 1)[1]
                break

    if not token:
        raise ConnectionRefusedError("Missing auth token")

    try:
        decoded = verify_token_string(token)
    except Exception as e:
        logger.warning(f"[Socket] rejected connection: {e}")
        raise ConnectionRefusedError("Invalid auth token")

    # Pre-populate the session with the verified identity.
    _sessions[sid] = {
        "userId": decoded.get("uid") or decoded.get("user_id") or "",
        "userName": decoded.get("name") or decoded.get("email", "").split("@")[0] or "Guest",
        "groupId": None,
        "kind": None,
        "email": decoded.get("email", ""),
    }
    logger.info("[Socket] Connected: %s (uid=%s)", sid, _sessions[sid]['userId'])



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
        db = SessionLocal()
        try:
            member = (
                db.query(GroupMember)
                .filter(
                    GroupMember.group_id == group_id,
                    GroupMember.user_firebase_uid == user_id,
                )
                .first()
            )
            if member:
                db.delete(member)
                db.commit()

            state = _build_blend_state(
                db,
                group_id,
                last_event={
                    "type": "member_left",
                    "userId": user_id,
                    "userName": user_name,
                },
            )
            await sio.emit("blend_state", state, room=group_id)
        except Exception as e:
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
        except Exception as e:
            logger.exception("[Socket] Error handling room disconnect")

        finally:
            db.close()


def _verified_uid(sid: str) -> str | None:
    """Return the verified uid for this sid, or None if not authenticated."""
    return _sessions.get(sid, {}).get("userId")


@sio.event
async def join_blend(sid, data):
    # Use the VERIFIED uid from the connect step, not the client-supplied one.
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    group_id = data.get("groupId")
    user_name = data.get("userName", _sessions[sid].get("userName", "Guest"))
    user_id = verified_uid  # VERIFIED — not client-supplied

    if not group_id or not user_id:
        await sio.emit("socket_error", "Missing groupId or userId", to=sid)
        return

    await sio.enter_room(sid, group_id)
    _sessions[sid] = {
        "groupId": group_id,
        "userId": user_id,
        "userName": user_name,
        "kind": "blend",
    }

    db = SessionLocal()
    try:
        group = db.query(Group).filter(Group.id == group_id).first()
        if not group:
            await sio.emit("socket_error", "Blend not found", to=sid)
            return

        existing = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_firebase_uid == user_id,
            )
            .first()
        )
        if not existing:
            db.add(
                GroupMember(
                    group_id=group_id,
                    user_firebase_uid=user_id,
                    user_name=user_name,
                )
            )
            db.commit()

        state = _build_blend_state(
            db,
            group_id,
            last_event={
                "type": "member_joined",
                "userId": user_id,
                "userName": user_name,
            },
        )
        await sio.emit("blend_state", state, to=sid)
        await sio.emit("blend_state", state, room=group_id, skip_sid=sid)
    except Exception as e:
        logger.exception("[Socket] Error joining blend")

        await sio.emit("socket_error", f"Join blend failed: {e}", to=sid)
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
    user_name = data.get("userName", _sessions[sid].get("userName", "Guest"))
    user_id = verified_uid  # VERIFIED
    swipe_type = (data.get("swipeType") or "like").lower()
    score = SCORE_MAP.get(swipe_type, 1)

    if not group_id or not product_id or not user_id:
        await sio.emit("socket_error", "Missing blend swipe fields", to=sid)
        return

    db = SessionLocal()
    try:
        existing = (
            db.query(GroupSwipe)
            .filter(
                GroupSwipe.group_id == group_id,
                GroupSwipe.user_firebase_uid == user_id,
                GroupSwipe.product_id == product_id,
            )
            .first()
        )
        if existing:
            existing.score = score
        else:
            db.add(
                GroupSwipe(
                    group_id=group_id,
                    user_firebase_uid=user_id,
                    product_id=product_id,
                    score=score,
                )
            )
        db.commit()

        state = _build_blend_state(
            db,
            group_id,
            last_event={
                "type": "swipe",
                "userId": user_id,
                "userName": user_name,
                "productId": product_id,
                "swipeType": swipe_type,
                "score": score,
            },
        )
        await sio.emit("blend_state", state, room=group_id)
    except Exception as e:
        logger.exception("[Socket] Error recording blend swipe")

        await sio.emit("socket_error", f"Swipe failed: {e}", to=sid)
    finally:
        db.close()


@sio.event
async def join_room(sid, data):
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    room_id = data.get("roomId")
    user_id = verified_uid  # VERIFIED
    user_name = data.get("userName", _sessions[sid].get("userName", "Guest"))
    options = data.get("options", [])

    if not room_id:
        await sio.emit("socket_error", "Missing roomId", to=sid)
        return

    await sio.enter_room(sid, room_id)
    _sessions[sid] = {
        "groupId": room_id,
        "userId": user_id,
        "userName": user_name,
        "kind": "room",
    }

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room:
            room = Room(
                id=room_id,
                query=room_id.replace("-", " ").title(),
                options=options,
                votes={},
                reactions=[],
                participant_count=1,
            )
            db.add(room)
        else:
            if not room.options and options:
                room.options = options
            room.participant_count = max(room.participant_count or 0, 0) + 1
        db.commit()
        db.refresh(room)

        group = db.query(Group).filter(Group.id == room_id).first()
        if not group:
            group = Group(id=room_id, name=room_id.replace("-", " ").title())
            db.add(group)
            db.commit()

        if user_id:
            existing_member = (
                db.query(GroupMember)
                .filter(
                    GroupMember.group_id == room_id,
                    GroupMember.user_firebase_uid == user_id,
                )
                .first()
            )
            if not existing_member:
                db.add(
                    GroupMember(
                        group_id=room_id,
                        user_firebase_uid=user_id,
                        user_name=user_name,
                    )
                )
                db.commit()

        vote_counts = {
            opt.get("id"): len(room.votes.get(opt.get("id"), []))
            for opt in (room.options or [])
            if opt.get("id")
        }
        state_payload = {
            "voteCounts": vote_counts,
            "reactions": room.reactions or [],
            "participantCount": room.participant_count,
            "lastVotedOptionId": None,
        }

        await sio.emit("room_state", state_payload, to=sid)
        await sio.emit("room_state", state_payload, room=room_id, skip_sid=sid)
    except Exception as e:
        logger.exception("[Socket] Error joining room")

        await sio.emit("socket_error", f"Join failed: {e}", to=sid)
    finally:
        db.close()


@sio.event
async def send_vote(sid, data):
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit("socket_error", "Not authenticated", to=sid)
        return

    room_id = data.get("roomId")
    option_id = data.get("optionId")
    user_id = verified_uid  # VERIFIED
    user_name = data.get("userName", _sessions[sid].get("userName", "Guest"))

    if not room_id or not option_id:
        await sio.emit("socket_error", "Missing room_id or option_id", to=sid)
        return

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room:
            await sio.emit("socket_error", "Room not found", to=sid)
            return

        votes = dict(room.votes) if room.votes else {}
        if option_id not in votes:
            votes[option_id] = []

        for opt_id in list(votes.keys()):
            if user_id in votes[opt_id]:
                votes[opt_id].remove(user_id)
        votes[option_id].append(user_id)
        room.votes = votes

        option_title = option_id
        for opt in room.options or []:
            if opt.get("id") == option_id:
                option_title = opt.get("title", option_id)
                break

        reactions = list(room.reactions or [])
        reactions.append(
            {
                "friendName": user_name,
                "emoji": "🔥",
                "note": f"Voted for {option_title}!",
                "optionId": option_id,
            }
        )
        room.reactions = reactions
        db.commit()
        db.refresh(room)

        if user_id:
            existing_swipe = (
                db.query(GroupSwipe)
                .filter(
                    GroupSwipe.group_id == room_id,
                    GroupSwipe.user_firebase_uid == user_id,
                    GroupSwipe.product_id == option_id,
                )
                .first()
            )
            if existing_swipe:
                existing_swipe.score = 1
            else:
                db.add(
                    GroupSwipe(
                        group_id=room_id,
                        user_firebase_uid=user_id,
                        product_id=option_id,
                        score=1,
                    )
                )
            db.commit()

        vote_counts = {
            opt.get("id"): len(room.votes.get(opt.get("id"), []))
            for opt in (room.options or [])
            if opt.get("id")
        }
        state_payload = {
            "voteCounts": vote_counts,
            "reactions": room.reactions,
            "participantCount": room.participant_count,
            "lastVotedOptionId": option_id,
        }
        await sio.emit("vote_updated", state_payload, room=room_id)

        if ENABLE_MOCK_SOCIAL:
            asyncio.create_task(_mock_friend_reaction(room_id, user_name))
    except Exception as e:
        logger.exception("[Socket] Error casting vote")

        await sio.emit("socket_error", f"Voting failed: {e}", to=sid)
    finally:
        db.close()


@sio.event
async def send_message(sid, data):
    verified_uid = _verified_uid(sid)
    if not verified_uid:
        await sio.emit('socket_error', 'Not authenticated', to=sid)
        return

    group_id = data.get('groupId')
    message = (data.get('message') or '').strip()
    user_id = verified_uid  # VERIFIED
    user_name = data.get('userName') or _sessions[sid].get('userName') or 'Guest'

    if not group_id or not user_id:
        await sio.emit('socket_error', 'Missing groupId/userId', to=sid)
        return
    if not message:
        await sio.emit('socket_error', 'Message cannot be empty', to=sid)
        return

    db = SessionLocal()
    try:
        # Ensure sender is a member of the group
        member = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_firebase_uid == user_id)
            .first()
        )
        if not member:
            await sio.emit('socket_error', 'Join the blend before messaging', to=sid)
            return

        msg = GroupMessage(
            group_id=group_id,
            sender_firebase_uid=user_id,
            sender_name=user_name,
            message=message,
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        payload = {
            'id': msg.id,
            'groupId': group_id,
            'senderId': user_id,
            'senderName': user_name,
            'message': message,
            'createdAt': msg.created_at.isoformat() if msg.created_at else None,
        }

        # Broadcast to blend participants room
        await sio.emit('message_created', payload, room=group_id)
    except Exception as e:
        logger.exception("[Socket] Error sending message")

        await sio.emit('socket_error', f"Message failed: {e}", to=sid)
    finally:
        db.close()


async def _mock_friend_reaction(room_id: str, voter_name: str) -> None:

    await asyncio.sleep(2.0)

    db = SessionLocal()
    try:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room or not room.options:
            return

        opt_to_vote = random.choice(room.options)
        opt_id = opt_to_vote.get("id")

        friends = ["Mia", "Zo", "Ari", "Kai"]
        friend = random.choice([f for f in friends if f.lower() != voter_name.lower()])
        friend_id = f"friend-{friend.lower()}"

        votes = dict(room.votes) if room.votes else {}
        if opt_id not in votes:
            votes[opt_id] = []
        for o_id in list(votes.keys()):
            if friend_id in votes[o_id]:
                votes[o_id].remove(friend_id)
        votes[opt_id].append(friend_id)
        room.votes = votes

        reactions = list(room.reactions or [])
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
            opt.get("id"): len(room.votes.get(opt.get("id"), []))
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
    except Exception as e:
        logger.exception("[Socket] Error in mock friend reaction")

    finally:
        db.close()
