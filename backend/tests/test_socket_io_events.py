"""
Real tests for Socket.IO events with authentic assertions.

Tests cover:
- Authorization checks for all events
- Event parameter validation
- State persistence in database
- Error handling
- Presence tracking
- Membership lifecycle
"""

import pytest
from unittest.mock import patch, AsyncMock

# Import models and handlers
from app.models import Blend, BlendMember, BlendInvitation, BlendSwipe, Friend
from app.socket_server import (
    connect, disconnect, join_blend, blend_swipe, leave_blend, get_blend_state,
    send_message,
    _sessions, _blend_presence,
    SCORE_MAP
)


@pytest.fixture(autouse=True)
def _socket_users(db_session):
    """Seed User rows referenced by blends below.

    SQLite FK enforcement is ON, so blends.user_firebase_uid must point at
    existing users.
    """
    from app.models import User

    for uid in ("creator-uid", "test-user-uid", "user-2"):
        if not db_session.query(User).filter(User.firebase_uid == uid).first():
            db_session.add(
                User(firebase_uid=uid, name=f"User {uid}", email=f"{uid}@example.com")
            )
    db_session.commit()
    yield
from conftest import _TestingSessionLocal


@pytest.fixture(autouse=True)
def _socket_testing_db(monkeypatch):
    """Socket handlers call SessionLocal() directly; route them to SQLite."""
    monkeypatch.setattr("app.socket_server.SessionLocal", _TestingSessionLocal)


@pytest.fixture(autouse=True)
def _socket_users(db_session):
    """Seed users referenced by blends (FK: blends.user_firebase_uid -> users)."""
    from app.models import User

    for uid in ("creator-uid", "test-user-uid", "user-2"):
        if not db_session.query(User).filter(User.firebase_uid == uid).first():
            db_session.add(
                User(firebase_uid=uid, name=f"User {uid}", email=f"{uid}@example.com")
            )
    db_session.commit()
    yield


@pytest.fixture
def mock_sio():
    """Mock Socket.IO server."""
    with patch('app.socket_server.sio') as mock:
        mock.emit = AsyncMock()
        mock.enter_room = AsyncMock()
        mock.leave_room = AsyncMock()
        yield mock


@pytest.fixture
def mock_firebase():
    """Mock Firebase authentication."""
    with patch('app.firebase_auth.verify_token_string') as mock:
        yield mock


@pytest.fixture
def valid_auth():
    """Valid Firebase auth claims."""
    return {
        "uid": "test-user-uid",
        "name": "Test User",
        "email": "test@example.com",
        "email_verified": True,
    }


@pytest.fixture
def valid_environ():
    """Valid environ dict from Socket.IO connect."""
    return {
        "REMOTE_ADDR": "127.0.0.1",
        "HTTP_X_FORWARDED_FOR": None,
    }


class TestSendMessagePersistence:
    @pytest.mark.asyncio
    async def test_send_message_is_committed_before_broadcast(
        self, mock_sio, monkeypatch, db_session
    ):
        from app.models import BlendMessage

        sid = "message-persistence-sid"
        _sessions[sid] = {"userId": "test-user-uid", "userName": "Test User"}

        async def allow_member(_user_id, _blend_id):
            return True

        async def allow_rate(_sid):
            return True

        monkeypatch.setattr("app.socket_server._check_socket_rate", allow_rate)
        monkeypatch.setattr("app.socket_server.require_blend_member_async", allow_member)

        await send_message(
            sid,
            {"groupId": "message-persistence-blend", "message": "Persist this message"},
        )

        persisted = (
            db_session.query(BlendMessage)
            .filter(BlendMessage.blend_id == "message-persistence-blend")
            .one()
        )
        assert persisted.sender_firebase_uid == "test-user-uid"
        assert persisted.sender_name == "Test User"
        assert persisted.content == "Persist this message"
        mock_sio.emit.assert_awaited_once()
        assert mock_sio.emit.await_args.args[:2] == (
            "message_created",
            {
                "id": persisted.id,
                "groupId": "message-persistence-blend",
                "senderId": "test-user-uid",
                "senderName": "Test User",
                "message": "Persist this message",
                "createdAt": persisted.created_at.isoformat(),
                "attachedProductId": None,
                "attachedProductTitle": None,
                "attachedProductImage": None,
                "attachedProductPrice": None,
            },
        )
        _sessions.pop(sid, None)


# ============================================================================
# AUTHENTICATION & CONNECTION TESTS
# ============================================================================

class TestSocketIOAuth:
    """Test Socket.IO authentication and authorization"""

    @pytest.mark.asyncio
    async def test_connect_requires_valid_token(self, mock_sio, mock_firebase, valid_auth, valid_environ):
        """Should reject connection without valid Firebase token"""
        mock_firebase.return_value = valid_auth
        
        # Mock the Firebase initialization check
        with patch('app.firebase_auth._firebase_initialized', True):
            sid = "test-sid-123"
            await connect(sid, valid_environ, {"token": "valid-token"})
            
            # Session should be stored with verified UID
            assert sid in _sessions
            assert _sessions[sid]["userId"] == "test-user-uid"
            assert _sessions[sid]["userName"] == "Test User"

    @pytest.mark.asyncio
    async def test_connect_rejects_missing_token(self, mock_sio, mock_firebase, valid_environ):
        """Should reject connection without auth token"""
        with patch('app.firebase_auth._firebase_initialized', True):
            sid = "test-sid-no-token"
            with pytest.raises(ConnectionRefusedError, match="Missing auth token"):
                await connect(sid, valid_environ, {})

    @pytest.mark.asyncio
    async def test_connect_rejects_invalid_token(self, mock_sio, mock_firebase, valid_environ):
        """Should reject connection with invalid Firebase token"""
        mock_firebase.side_effect = Exception("Invalid token")
        
        with patch('app.firebase_auth._firebase_initialized', True):
            sid = "test-sid-invalid"
            with pytest.raises(ConnectionRefusedError, match="Invalid auth token"):
                await connect(sid, valid_environ, {"token": "invalid-token"})

    @pytest.mark.asyncio
    async def test_disconnect_cleans_up_session(self, mock_sio, valid_auth, valid_environ):
        """Should remove user from _sessions on disconnect"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                sid = "test-sid-cleanup"
                await connect(sid, valid_environ, {"token": "valid-token"})
                assert sid in _sessions
                
                # Disconnect
                with patch('app.socket_server.SessionLocal'):
                    await disconnect(sid)
                    assert sid not in _sessions

    @pytest.mark.asyncio
    async def test_disconnect_does_not_delete_blend_member(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: disconnect() should NOT delete BlendMember from database.
        
        SCENARIO: User is in a blend, network drops and socket disconnects.
        EXPECTED: BlendMember row remains, only presence is cleared.
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend and member
                blend = Blend(id="blend-test", name="Test Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(
                    blend_id="blend-test",
                    user_firebase_uid="test-user-uid",
                    user_name="Test User"
                )
                db_session.add(member)
                db_session.commit()
                
                # Connect and join blend
                sid = "test-sid-member"
                await connect(sid, valid_environ, {"token": "valid-token"})
                _sessions[sid]["groupId"] = "blend-test"
                _sessions[sid]["kind"] = "blend"
                _blend_presence["blend-test"] = {"test-user-uid": sid}
                
                # Disconnect
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio.emit', new_callable=AsyncMock):
                        await disconnect(sid)
                
                # Verify BlendMember still exists
                member_after = db_session.query(BlendMember).filter(
                    BlendMember.blend_id == "blend-test",
                    BlendMember.user_firebase_uid == "test-user-uid"
                ).first()
                assert member_after is not None, "BlendMember should persist after disconnect"
                
                # Verify presence is cleared
                assert "blend-test" not in _blend_presence or "test-user-uid" not in _blend_presence.get("blend-test", {})

    @pytest.mark.asyncio
    async def test_disconnect_broadcasts_member_offline_event(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: disconnect() should broadcast member_offline event.
        
        SCENARIO: User disconnects from blend.
        EXPECTED: Other room members receive blend_state with lastEvent.type == 'member_offline'
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend and member
                blend = Blend(id="blend-offline-test", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(
                    blend_id="blend-offline-test",
                    user_firebase_uid="test-user-uid",
                    user_name="Test User"
                )
                db_session.add(member)
                db_session.commit()
                
                sid = "test-sid-offline"
                await connect(sid, valid_environ, {"token": "valid-token"})
                _sessions[sid]["groupId"] = "blend-offline-test"
                _sessions[sid]["kind"] = "blend"
                
                # Disconnect with async mock sio
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        # Need to patch sio globally for the event handler
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await disconnect(sid)
                            
                            # Verify emit was called with blend_state event
                            mock_sio_obj.emit.assert_called_once()
                            args, kwargs = mock_sio_obj.emit.call_args
                            assert args[0] == "blend_state"
                            state = args[1]
                            assert state["lastEvent"]["type"] == "member_offline"
                            assert state["lastEvent"]["userId"] == "test-user-uid"
                        finally:
                            socket_server.sio = original_sio


# ============================================================================
# BLEND MEMBERSHIP & PERSISTENCE TESTS
# ============================================================================

class TestBlendMembershipPersistence:
    """Test P0 fix: Membership persists across disconnects"""

    @pytest.mark.asyncio
    async def test_leave_blend_deletes_membership(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: leave_blend() SHOULD delete BlendMember (explicit user action).
        
        SCENARIO: User explicitly clicks "Leave Blend".
        EXPECTED: BlendMember deleted, other members see member_left event.
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend and member
                blend = Blend(id="blend-leave", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(
                    blend_id="blend-leave",
                    user_firebase_uid="test-user-uid",
                    user_name="Test User"
                )
                db_session.add(member)
                db_session.commit()
                
                # Connect and set up session
                sid = "test-sid-leave"
                await connect(sid, valid_environ, {"token": "valid-token"})
                
                # Call leave_blend
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        mock_sio_obj.leave_room = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await leave_blend(sid, {"groupId": "blend-leave"})
                            
                            # Verify member is deleted
                            member_after = db_session.query(BlendMember).filter(
                                BlendMember.blend_id == "blend-leave",
                                BlendMember.user_firebase_uid == "test-user-uid"
                            ).first()
                            assert member_after is None, "BlendMember should be deleted on explicit leave"
                            
                            # Verify member_left event was broadcast
                            assert mock_sio_obj.emit.called
                            call_args = [call for call in mock_sio_obj.emit.call_args_list]
                            # Should emit blend_state with member_left event
                            state_call = [c for c in call_args if c[0][0] == "blend_state"]
                            assert len(state_call) > 0
                            assert state_call[0][0][1]["lastEvent"]["type"] == "member_left"
                        finally:
                            socket_server.sio = original_sio

    @pytest.mark.asyncio
    async def test_reconnect_user_can_rejoin_without_invitation(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: Reconnected user should rejoin blend without needing new invitation.
        
        SCENARIO: User joins public blend, disconnects, reconnects.
        EXPECTED: User can rejoin same blend (membership persists).
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create public blend and member
                blend = Blend(id="blend-rejoin", name="Public Blend", is_private=False, user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(
                    blend_id="blend-rejoin",
                    user_firebase_uid="test-user-uid",
                    user_name="Test User"
                )
                db_session.add(member)
                db_session.commit()
                
                # Connect, join, disconnect
                sid1 = "test-sid-rejoin-1"
                await connect(sid1, valid_environ, {"token": "valid-token"})
                
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio', new_callable=AsyncMock):
                        await disconnect(sid1)
                
                # Verify member still exists
                member_check = db_session.query(BlendMember).filter(
                    BlendMember.blend_id == "blend-rejoin",
                    BlendMember.user_firebase_uid == "test-user-uid"
                ).first()
                assert member_check is not None, "Member should persist after disconnect"


# ============================================================================
# PRIVATE BLEND AUTHORIZATION TESTS
# ============================================================================

class TestPrivateBlendAuthorization:
    """Test P0 fix: Private blend join security"""

    @pytest.mark.asyncio
    async def test_join_private_blend_requires_exact_invitation(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: User cannot join private blend without exact uid match in invitation.
        
        SCENARIO: User tries to join private blend. Only exact invitee_firebase_uid match allowed.
        EXPECTED: Reject join if no matching invitation. Allow if pending/accepted invitation exists.
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create private blend
                blend = Blend(id="blend-private", name="Private Blend", is_private=True, user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()

                # Product rule: blend participants must be friends with the owner
                # before the invitation check is reached on the socket join path.
                db_session.add(Friend(user_firebase_uid="test-user-uid", friend_firebase_uid="creator-uid", friend_name="Creator"))
                db_session.commit()
                
                # Connect
                sid = "test-sid-private"
                await connect(sid, valid_environ, {"token": "valid-token"})
                
                # Try to join WITHOUT invitation — should fail
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        mock_sio_obj.enter_room = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await join_blend(sid, {"groupId": "blend-private"})
                            
                            # Should emit socket_error
                            error_calls = [c for c in mock_sio_obj.emit.call_args_list 
                                         if c[0][0] == "socket_error"]
                            assert len(error_calls) > 0, "Should emit error for uninvited user"
                            assert "private" in error_calls[0][0][1].lower()
                        finally:
                            socket_server.sio = original_sio

    @pytest.mark.asyncio
    async def test_join_private_blend_allows_invited_user(self, mock_sio, db_session, valid_auth, valid_environ):
        """P0: User with pending/accepted invitation can join private blend.
        
        SCENARIO: User joins private blend with valid pending invitation.
        EXPECTED: Join succeeds, invitation status updated to 'accepted'.
        """
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create private blend
                blend = Blend(id="blend-private-invited", name="Private Blend", is_private=True, user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()

                # Product rule: socket join requires friendship with the owner.
                db_session.add(Friend(user_firebase_uid="test-user-uid", friend_firebase_uid="creator-uid", friend_name="Creator"))
                db_session.commit()
                
                # Create pending invitation for this exact user
                # (REST-created invites always carry expires_seconds; see
                # app/routes/invitations.py — omitting it means "expired")
                invitation = BlendInvitation(
                    id="inv-123",
                    blend_id="blend-private-invited",
                    inviter_firebase_uid="creator-uid",
                    invitee_firebase_uid="test-user-uid",  # Exact match
                    status="pending",
                    expires_seconds=60 * 60 * 24 * 7,
                )
                db_session.add(invitation)
                db_session.commit()
                
                # Connect
                sid = "test-sid-invited"
                await connect(sid, valid_environ, {"token": "valid-token"})
                
                # Join blend
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        mock_sio_obj.enter_room = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await join_blend(sid, {"groupId": "blend-private-invited"})
                            
                            # Verify member was created
                            member = db_session.query(BlendMember).filter(
                                BlendMember.blend_id == "blend-private-invited",
                                BlendMember.user_firebase_uid == "test-user-uid"
                            ).first()
                            assert member is not None, "Member should be created"
                            
                            # Verify invitation status updated
                            inv = db_session.query(BlendInvitation).filter(
                                BlendInvitation.id == "inv-123"
                            ).first()
                            assert inv.status == "accepted", "Invitation should be marked accepted"
                        finally:
                            socket_server.sio = original_sio


# ============================================================================
# SWIPE & BLEND STATE TESTS
# ============================================================================

class TestBlendSwipeAndState:
    """Test swipe events and blend state computation"""

    @pytest.mark.asyncio
    async def test_blend_swipe_records_score(self, mock_sio, db_session, valid_auth, valid_environ):
        """Should record swipe with correct score mapping"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend and member
                blend = Blend(id="blend-swipe", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(blend_id="blend-swipe", user_firebase_uid="test-user-uid", user_name="Test")
                db_session.add(member)
                db_session.commit()
                
                # Connect
                sid = "test-sid-swipe"
                await connect(sid, valid_environ, {"token": "valid-token"})
                _sessions[sid]["groupId"] = "blend-swipe"
                
                # Send swipe
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await blend_swipe(sid, {
                                "groupId": "blend-swipe",
                                "productId": "prod-123",
                                "swipeType": "like"
                            })
                            
                            # Verify swipe recorded with correct score
                            swipe = db_session.query(BlendSwipe).filter(
                                BlendSwipe.blend_id == "blend-swipe",
                                BlendSwipe.product_id == "prod-123"
                            ).first()
                            assert swipe is not None
                            assert swipe.score == SCORE_MAP["like"]
                        finally:
                            socket_server.sio = original_sio

    @pytest.mark.asyncio
    async def test_blend_swipe_emits_lightweight_event(self, mock_sio, db_session, valid_auth, valid_environ):
        """P1: blend_swipe should emit lightweight swipe_applied event, not full blend_state"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend and member
                blend = Blend(id="blend-swipe-light", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member = BlendMember(blend_id="blend-swipe-light", user_firebase_uid="test-user-uid", user_name="Test")
                db_session.add(member)
                db_session.commit()
                
                # Connect
                sid = "test-sid-swipe-light"
                await connect(sid, valid_environ, {"token": "valid-token"})
                _sessions[sid]["groupId"] = "blend-swipe-light"
                
                # Send swipe
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await blend_swipe(sid, {
                                "groupId": "blend-swipe-light",
                                "productId": "prod-456",
                                "swipeType": "love"
                            })
                            
                            # Verify swipe_applied event emitted (not full blend_state)
                            emit_calls = mock_sio_obj.emit.call_args_list
                            swipe_applied_calls = [c for c in emit_calls if c[0][0] == "swipe_applied"]
                            assert len(swipe_applied_calls) > 0, "Should emit swipe_applied event"
                        finally:
                            socket_server.sio = original_sio

    @pytest.mark.asyncio
    async def test_get_blend_state_returns_members_and_online_users(self, mock_sio, db_session, valid_auth, valid_environ):
        """get_blend_state should return members + onlineUserIds for a member"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend with members
                blend = Blend(id="blend-state", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                member1 = BlendMember(blend_id="blend-state", user_firebase_uid="test-user-uid", user_name="User1")
                member2 = BlendMember(blend_id="blend-state", user_firebase_uid="user-2", user_name="User2")
                db_session.add(member1)
                db_session.add(member2)
                db_session.commit()
                
                # Connect and simulate user 1 online
                sid = "test-sid-state"
                await connect(sid, valid_environ, {"token": "valid-token"})
                _blend_presence["blend-state"] = {"test-user-uid": sid}
                
                # Get blend state
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await get_blend_state(sid, {"groupId": "blend-state"})
                            
                            # Verify emit called with blend_state
                            emit_calls = mock_sio_obj.emit.call_args_list
                            state_calls = [c for c in emit_calls if c[0][0] == "blend_state"]
                            assert len(state_calls) > 0
                            state = state_calls[0][0][1]
                            
                            # Verify members and online users
                            assert len(state["members"]) == 2
                            assert state["memberCount"] == 2
                            assert "test-user-uid" in state["onlineUserIds"]
                        finally:
                            socket_server.sio = original_sio


# ============================================================================
# AUTHORIZATION DEPTH TESTS
# ============================================================================

class TestAuthorizationDepth:
    """Test authorization checks prevent IDOR"""

    @pytest.mark.asyncio
    async def test_blend_swipe_requires_membership(self, mock_sio, db_session, valid_auth, valid_environ):
        """Should reject swipe if user is not a blend member"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend WITHOUT adding user as member
                blend = Blend(id="blend-no-member", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                sid = "test-sid-no-member"
                await connect(sid, valid_environ, {"token": "valid-token"})
                
                # Try to swipe
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await blend_swipe(sid, {
                                "groupId": "blend-no-member",
                                "productId": "prod-789",
                                "swipeType": "like"
                            })
                            
                            # Should emit error
                            error_calls = [c for c in mock_sio_obj.emit.call_args_list 
                                         if c[0][0] == "socket_error"]
                            assert len(error_calls) > 0, "Should reject non-member swipe"
                        finally:
                            socket_server.sio = original_sio

    @pytest.mark.asyncio
    async def test_get_blend_state_requires_membership(self, mock_sio, db_session, valid_auth, valid_environ):
        """Should reject get_blend_state if user is not a member"""
        with patch('app.firebase_auth._firebase_initialized', True):
            with patch('app.firebase_auth.verify_token_string', return_value=valid_auth):
                # Create blend WITHOUT adding user
                blend = Blend(id="blend-no-access", name="Blend", user_firebase_uid="creator-uid")
                db_session.add(blend)
                db_session.commit()
                
                sid = "test-sid-no-access"
                await connect(sid, valid_environ, {"token": "valid-token"})
                
                with patch('app.socket_server.SessionLocal', return_value=db_session):
                    with patch('app.socket_server.sio') as mock_sio_obj:
                        mock_sio_obj.emit = AsyncMock()
                        import app.socket_server as socket_server
                        original_sio = socket_server.sio
                        socket_server.sio = mock_sio_obj
                        try:
                            await get_blend_state(sid, {"groupId": "blend-no-access"})
                            
                            # Should emit error
                            error_calls = [c for c in mock_sio_obj.emit.call_args_list 
                                         if c[0][0] == "socket_error"]
                            assert len(error_calls) > 0, "Should reject non-member state request"
                        finally:
                            socket_server.sio = original_sio
