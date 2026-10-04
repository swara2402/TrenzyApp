"""Social posts: CRUD, likes, and comments.

Endpoints:
- POST /api/posts — create a new post
- GET /api/posts — list posts (optionally filtered by user_id)
- DELETE /api/posts/{id} — delete own post only
- POST /api/posts/{id}/like — toggle like (idempotent)
- DELETE /api/posts/{id}/like — remove like
- POST /api/posts/{id}/comment — add a comment
- GET /api/posts/{id}/comments — list all comments on a post

Post listing includes up to 3 most recent comments and aggregate like/comment
counts to avoid N+1 queries. The ``user_liked`` flag tells the client whether
the current user has liked each post.
"""
import logging
from collections import defaultdict
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, delete, func
from sqlalchemy.orm import Session

from ..db import get_session
from ..firebase_auth import verify_firebase_token
from ..models import Post, Like, Comment, User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/posts", tags=["posts"])


class CreatePostRequest(BaseModel):
    content: str = Field(..., max_length=2000)
    attachment: Optional[str] = Field(None, max_length=500)


class CommentOnPostRequest(BaseModel):
    content: str = Field(..., max_length=1000)


def _get_uid(auth_value: object) -> str | None:
    if isinstance(auth_value, dict):
        return auth_value.get("uid") or auth_value.get("firebase_uid") or auth_value.get("user_id")
    if auth_value is None:
        return None
    return str(auth_value)


@router.post("")
async def create_post(
    payload: CreatePostRequest,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    user = session.execute(
        select(User).where(User.firebase_uid == auth_uid_value)
    ).scalar_one_or_none()
    user_name = user.name if user else "User"
    
    post = Post(
        user_firebase_uid=auth_uid_value,
        user_name=user_name,
        content=payload.content,
        attachment=payload.attachment,
    )
    session.add(post)
    session.commit()
    session.refresh(post)
    
    return {
        "id": post.id,
        "user_firebase_uid": post.user_firebase_uid,
        "user_name": post.user_name,
        "content": post.content,
        "attachment": post.attachment,
        "created_at": post.created_at.isoformat() if post.created_at is not None else None,
        "like_count": 0,
        "comment_count": 0,
    }


@router.get("")
async def get_posts(
    user_id: Optional[str] = None,
    offset: int = 0,
    limit: int = 20,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    limit = max(1, min(limit, 100))
    offset = max(0, offset)
    query = select(Post)
    if user_id:
        query = query.where(Post.user_firebase_uid == user_id)
    query = query.order_by(Post.created_at.desc()).offset(offset).limit(limit)
    posts = session.execute(query).scalars().all()
    if not posts:
        return {"posts": []}

    post_ids = [p.id for p in posts]

    like_counts = {row[0]: row[1] for row in session.execute(
        select(Like.post_id, func.count(Like.id))
        .where(Like.post_id.in_(post_ids))
        .group_by(Like.post_id)
    ).all()}

    comment_counts = {row[0]: row[1] for row in session.execute(
        select(Comment.post_id, func.count(Comment.id))
        .where(Comment.post_id.in_(post_ids))
        .group_by(Comment.post_id)
    ).all()}

    user_liked_ids = set()
    if auth_uid_value:
        user_liked_ids = {
            row[0] for row in session.execute(
                select(Like.post_id)
                .where(
                    Like.post_id.in_(post_ids),
                    Like.user_firebase_uid == auth_uid_value,
                )
            ).all()
        }

    # Bound comment loading to the 3 most recent per post instead of loading
    # every comment for every post into Python.
    windowed = (
        select(
            Comment.id.label("cid"),
            func.row_number().over(
                partition_by=Comment.post_id,
                order_by=Comment.created_at.desc(),
            ).label("rn"),
        )
        .where(Comment.post_id.in_(post_ids))
        .subquery()
    )
    top_comment_ids = [
        row.cid
        for row in session.execute(select(windowed.c.cid).where(windowed.c.rn <= 3)).all()
    ]
    all_comments: dict[str, list[Comment]] = defaultdict(list)
    if top_comment_ids:
        for c in session.execute(
            select(Comment)
            .where(Comment.id.in_(top_comment_ids))
            .order_by(Comment.created_at.desc())
        ).scalars().all():
            all_comments[c.post_id].append(c)

    result = []
    for post in posts:
        comments = all_comments.get(post.id, [])
        result.append({
            "id": post.id,
            "user_firebase_uid": post.user_firebase_uid,
            "user_name": post.user_name,
            "content": post.content,
            "attachment": post.attachment,
            "created_at": post.created_at.isoformat() if post.created_at is not None else None,
            "like_count": like_counts.get(post.id, 0),
            "comment_count": comment_counts.get(post.id, 0),
            "user_liked": post.id in user_liked_ids,
            "comments": [{"id": c.id, "user_firebase_uid": c.user_firebase_uid, "content": c.content, "created_at": c.created_at.isoformat() if c.created_at is not None else None} for c in comments],
        })
    
    return {"posts": result}


@router.delete("/{post_id}")
async def delete_post(
    post_id: int,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    post = session.execute(
        select(Post).where(Post.id == post_id)
    ).scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    user = session.execute(
        select(User).where(User.firebase_uid == auth_uid_value)
    ).scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if post.user_firebase_uid != auth_uid_value and not user.is_admin:
        raise HTTPException(status_code=403, detail="Not authorized to delete this post")
    session.delete(post)
    session.commit()
    return {"ok": True}


@router.post("/{post_id}/like")
async def like_post(
    post_id: int,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    existing = session.execute(
        select(Like).where(
            Like.post_id == post_id,
            Like.user_firebase_uid == auth_uid_value,
        )
    ).first()
    if existing:
        return {"ok": True, "liked": True}
    session.add(Like(post_id=post_id, user_firebase_uid=auth_uid_value))
    session.commit()
    return {"ok": True, "liked": True}


@router.delete("/{post_id}/like")
async def unlike_post(
    post_id: int,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    session.execute(
        delete(Like).where(
            Like.post_id == post_id,
            Like.user_firebase_uid == auth_uid_value,
        )
    )
    session.commit()
    return {"ok": True, "liked": False}


@router.post("/{post_id}/comment")
async def comment_on_post(
    post_id: int,
    payload: CommentOnPostRequest,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    comment = Comment(
        post_id=post_id,
        user_firebase_uid=auth_uid_value,
        content=payload.content,
    )
    session.add(comment)
    session.commit()
    session.refresh(comment)
    return {
        "id": comment.id,
        "post_id": comment.post_id,
        "user_firebase_uid": comment.user_firebase_uid,
        "content": comment.content,
        "created_at": comment.created_at.isoformat() if comment.created_at is not None else None,
    }


@router.delete("/{post_id}/comment/{comment_id}")
async def delete_comment(
    post_id: int,
    comment_id: int,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    auth_uid_value = _get_uid(auth_uid)
    if not auth_uid_value:
        raise HTTPException(status_code=401, detail="Missing uid claim")

    comment = session.execute(
        select(Comment).where(Comment.id == comment_id, Comment.post_id == post_id)
    ).scalar_one_or_none()

    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")

    post = session.execute(
        select(Post).where(Post.id == post_id)
    ).scalar_one_or_none()

    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    user = session.execute(
        select(User).where(User.firebase_uid == auth_uid_value)
    ).scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Authorization check: comment author, post author, or admin
    if not (
        comment.user_firebase_uid == auth_uid_value
        or post.user_firebase_uid == auth_uid_value
        or user.is_admin
    ):
        raise HTTPException(status_code=403, detail="Not authorized to delete this comment")

    session.delete(comment)
    session.commit()
    return {"ok": True}


@router.get("/{post_id}/comments")
async def get_comments(
    post_id: int,
    offset: int = 0,
    limit: int = 50,
    auth_uid: object = Depends(verify_firebase_token),
    session: Session = Depends(get_session),
):
    _ = _get_uid(auth_uid)
    limit = max(1, min(limit, 200))
    offset = max(0, offset)
    stmt = (
        select(Comment)
        .where(Comment.post_id == post_id)
        .order_by(Comment.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    comments = session.execute(stmt).scalars().all()
    return {"comments": [{"id": c.id, "post_id": c.post_id, "user_firebase_uid": c.user_firebase_uid, "content": c.content, "created_at": c.created_at.isoformat() if c.created_at is not None else None} for c in comments]}