"""Tests for real blend invite codes.

Covers the contract that ``inviteCode`` is a dedicated random code (never the
blend id), that join-by-code resolves via ``invite_code``, and that private
blends still require a valid invitation. Cross-user behaviour is exercised by
monkeypatching the blends module's ``verify_firebase_token`` with a header
driven fake (the dev bypass is locked to a single UID).
"""

import uuid

import pytest
from app.models import Blend, BlendMember, Friend, User


CODE_ALPHABET = set("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

OWNER_UID = "blend-test-owner"


def _seed_friendship(db, a: str, b: str) -> None:
    """Establish the mutual friendship the blend-join product rule requires.

    ``POST /api/blends/join`` rejects non-friends with 403; joiners in these
    tests are otherwise transient uids with no relationship to the owner.
    """
    db.add(Friend(user_firebase_uid=a, friend_firebase_uid=b, friend_name="f"))
    db.commit()


@pytest.fixture
def multi_user_auth(monkeypatch):
    """Patch blends auth so `Authorization: Bearer <UID>` authenticates as UID."""

    def _fake_verify(request):
        from fastapi import HTTPException

        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing authentication token")
        uid = header[len("Bearer "):].strip()
        if not uid:
            raise HTTPException(status_code=401, detail="Missing authentication token")
        return {"uid": uid, "name": f"User {uid}"}

    monkeypatch.setattr(
        "app.routes.blends.verify_firebase_token", _fake_verify, raising=True
    )
    return _fake_verify


@pytest.fixture(autouse=True)
def _blend_test_data(db_session):
    """blends.user_firebase_uid → users.firebase_uid FK needs the owner row;
    joiners are safe without one (BlendMember.uid has no FK)."""
    if not db_session.query(User).filter(User.firebase_uid == OWNER_UID).first():
        db_session.add(
            User(
                firebase_uid=OWNER_UID,
                name="Blend Test Owner",
                email=f"{OWNER_UID}@example.com",
            )
        )
        db_session.commit()
    yield
    db_session.query(BlendMember).delete()
    db_session.query(Blend).delete()
    db_session.commit()


def _auth(uid: str) -> dict:
    return {"Authorization": f"Bearer {uid}"}


def _new_uid(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8]}"


def _create_blend(client, name: str, **overrides) -> dict:
    payload = {"name": name}
    payload.update(overrides)
    res = client.post("/api/blends", json=payload, headers=_auth(OWNER_UID))
    assert res.status_code == 200, res.text
    return res.json()


# ────────────────────────────────────────────────────────────
# Create returns a real invite code (not the blend id)
# ────────────────────────────────────────────────────────────

def test_create_blend_returns_real_invite_code(client, db_session, multi_user_auth):
    body = _create_blend(client, "Invite Code Crew")
    code = body.get("inviteCode", "")

    assert code, "inviteCode must be present"
    assert code != body["id"], "inviteCode must NOT be the blend id"
    assert len(code) == 6, "invite codes are 6 characters"
    assert set(code) <= CODE_ALPHABET, f"unexpected characters in code: {code}"

    row = db_session.query(Blend).filter(Blend.id == body["id"]).first()
    assert row is not None
    assert row.invite_code == code, "code must be persisted on the Blend row"

    # Two blends never share a code
    other = _create_blend(client, "Second Crew")
    assert other["inviteCode"] != code


# ────────────────────────────────────────────────────────────
# Join by invite code resolves to the right blend
# ────────────────────────────────────────────────────────────

def test_join_by_invite_code(client, db_session, multi_user_auth):
    joiner = _new_uid("joiner")
    _seed_friendship(db_session, joiner, OWNER_UID)

    created = _create_blend(client, "Joinable Crew")
    code = created["inviteCode"]

    # Join with the CODE (not the id) — lowercase input resolves too.
    res = client.post(
        "/api/blends/join",
        json={"groupId": code.lower()},
        headers=_auth(joiner),
    )
    assert res.status_code == 200, res.text
    joined = res.json()

    # Response exposes the real id + stable invite code
    assert joined["id"] == created["id"]
    assert joined["inviteCode"] == code

    member = (
        db_session.query(BlendMember)
        .filter(
            BlendMember.blend_id == created["id"],
            BlendMember.user_firebase_uid == joiner,
        )
        .first()
    )
    assert member is not None, "join-by-code must create membership on the real blend"


def test_join_by_unknown_code_returns_404(client, multi_user_auth):
    res = client.post(
        "/api/blends/join",
        json={"groupId": "ZZZZZZ"},
        headers=_auth(_new_uid("ghost")),
    )
    assert res.status_code == 404


def test_join_by_blend_id_still_works(client, db_session, multi_user_auth):
    """Back-compat: existing flows pass the blend id directly."""
    joiner = _new_uid("joiner")
    _seed_friendship(db_session, joiner, OWNER_UID)

    created = _create_blend(client, "Id Join Crew")

    res = client.post(
        "/api/blends/join",
        json={"groupId": created["id"]},
        headers=_auth(joiner),
    )
    assert res.status_code == 200
    assert res.json()["id"] == created["id"]


# ────────────────────────────────────────────────────────────
# Private blends still require an invitation
# ────────────────────────────────────────────────────────────

def test_private_blend_rejects_code_join_without_invitation(client, multi_user_auth):
    outsider = _new_uid("outsider")

    created = _create_blend(client, "Secret Crew", isPrivate=True)

    res = client.post(
        "/api/blends/join",
        json={"groupId": created["inviteCode"]},
        headers=_auth(outsider),
    )
    assert res.status_code == 403, "private blends must require an invitation"


# ────────────────────────────────────────────────────────────
# Per-user join rate limit (in-memory only; see note in blends.py)
# ────────────────────────────────────────────────────────────

def test_join_rate_limit_per_user(client, db_session, multi_user_auth):
    from app.routes import blends as blends_module

    spammer = _new_uid("spammer")  # unique uid → isolated in-memory bucket
    _seed_friendship(db_session, spammer, OWNER_UID)

    created = _create_blend(client, "Rate Limited Crew")

    last_status = None
    for _ in range(blends_module._MAX_JOINS_PER_MINUTE + 2):
        res = client.post(
            "/api/blends/join",
            json={"groupId": created["id"]},
            headers=_auth(spammer),
        )
        last_status = res.status_code
        if last_status == 429:
            break
    assert last_status == 429, "joins beyond the per-minute cap must be limited"
