"""Friends isolation, request flow, and auto-accept tests."""

import uuid

import pytest
from app.models import Friend, FriendRequest, User

A_UID = "friend-user-a"
B_UID = "friend-user-b"
C_UID = "friend-user-c"


@pytest.fixture
def multi_user_auth(monkeypatch):
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
        "app.routes.friends.verify_firebase_token", _fake_verify, raising=True
    )
    return _fake_verify


@pytest.fixture(autouse=True)
def _friend_users(db_session):
    for uid in (A_UID, B_UID, C_UID):
        if not db_session.query(User).filter(User.firebase_uid == uid).first():
            db_session.add(
                User(firebase_uid=uid, name=f"User {uid}", email=f"{uid}@example.com")
            )
    db_session.commit()
    yield
    db_session.query(Friend).delete()
    db_session.query(FriendRequest).delete()
    db_session.commit()


def _auth(uid: str) -> dict:
    return {"Authorization": f"Bearer {uid}"}


def test_unauthenticated_friends(client):
    assert client.get("/api/friends").status_code == 401
    assert client.get("/api/friends/requests").status_code == 401


def test_send_and_list_incoming(client, multi_user_auth):
    res = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    )
    assert res.status_code == 200, res.text
    request_id = res.json()["requestId"]

    incoming = client.get("/api/friends/requests", headers=_auth(B_UID))
    assert incoming.status_code == 200
    reqs = incoming.json()["requests"]
    assert len(reqs) == 1
    assert reqs[0]["id"] == request_id
    assert reqs[0]["fromFirebaseUid"] == A_UID

    # Sender should not see it as incoming
    a_in = client.get("/api/friends/requests", headers=_auth(A_UID))
    assert a_in.json()["requests"] == []

    outgoing = client.get(
        "/api/friends/requests?box=outgoing", headers=_auth(A_UID)
    )
    assert len(outgoing.json()["requests"]) == 1


def test_cannot_friend_self(client, multi_user_auth):
    res = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": A_UID},
        headers=_auth(A_UID),
    )
    assert res.status_code == 400


def test_unknown_user_404(client, multi_user_auth):
    res = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": f"missing-{uuid.uuid4().hex[:6]}"},
        headers=_auth(A_UID),
    )
    assert res.status_code == 404


def test_duplicate_pending_rejected(client, multi_user_auth):
    client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    )
    res = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    )
    assert res.status_code == 400


def test_accept_creates_mutual_friends(client, multi_user_auth):
    created = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    ).json()
    rid = created["requestId"]

    acc = client.post(
        f"/api/friends/requests/{rid}/accept",
        headers=_auth(B_UID),
    )
    assert acc.status_code == 200, acc.text

    a_friends = client.get("/api/friends", headers=_auth(A_UID)).json()["friends"]
    b_friends = client.get("/api/friends", headers=_auth(B_UID)).json()["friends"]
    assert any(f["friendFirebaseUid"] == B_UID for f in a_friends)
    assert any(f["friendFirebaseUid"] == A_UID for f in b_friends)


def test_cannot_accept_someone_elses_request(client, multi_user_auth):
    rid = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    ).json()["requestId"]

    res = client.post(
        f"/api/friends/requests/{rid}/accept",
        headers=_auth(C_UID),
    )
    assert res.status_code == 404

    res_rej = client.post(
        f"/api/friends/requests/{rid}/reject",
        headers=_auth(C_UID),
    )
    assert res_rej.status_code == 404


def test_remove_is_mutual_and_isolated(client, multi_user_auth):
    rid = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    ).json()["requestId"]
    client.post(f"/api/friends/requests/{rid}/accept", headers=_auth(B_UID))

    a_friends = client.get("/api/friends", headers=_auth(A_UID)).json()["friends"]
    row_id = a_friends[0]["id"]

    # C cannot delete A's friendship
    sneak = client.delete(f"/api/friends/{row_id}", headers=_auth(C_UID))
    assert sneak.status_code == 404

    gone = client.delete(f"/api/friends/{row_id}", headers=_auth(A_UID))
    assert gone.status_code == 200
    assert client.get("/api/friends", headers=_auth(A_UID)).json()["friends"] == []
    assert client.get("/api/friends", headers=_auth(B_UID)).json()["friends"] == []


def test_reverse_request_auto_accepts(client, multi_user_auth):
    client.post(
        "/api/friends/request",
        json={"toFirebaseUid": B_UID},
        headers=_auth(A_UID),
    )
    res = client.post(
        "/api/friends/request",
        json={"toFirebaseUid": A_UID},
        headers=_auth(B_UID),
    )
    assert res.status_code == 200, res.text
    assert res.json().get("autoAccepted") is True

    a_friends = client.get("/api/friends", headers=_auth(A_UID)).json()["friends"]
    assert any(f["friendFirebaseUid"] == B_UID for f in a_friends)
