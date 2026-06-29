from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from ..db import SessionLocal
from ..firebase_auth import verify_firebase_token
from ..models import User

router = APIRouter(prefix="/api/users", tags=["users"])


from typing import Optional

class UserUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)



def _user_payload(user: User) -> dict[str, Any]:
    return {
        "id": user.id,
        "firebaseUid": user.firebase_uid,
        "name": user.name,
        "email": user.email,
    }


@router.patch("/me")
def update_me(payload: UserUpdateRequest, request: Request) -> dict[str, Any]:
    decoded = verify_firebase_token(request)
    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    if payload.name is None:
        raise HTTPException(status_code=400, detail="No fields to update")

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
        if not user:
            user = User(
                firebase_uid=firebase_uid,
                name=payload.name or decoded.get("name") or "",
                email=decoded.get("email"),
            )
            db.add(user)
        else:
            user.name = payload.name

        db.commit()
        db.refresh(user)
        return {"user": _user_payload(user)}
    finally:
        db.close()
