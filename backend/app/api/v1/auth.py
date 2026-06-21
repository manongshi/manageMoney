from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import ApiError
from app.core.responses import success
from app.core.security import create_access_token, get_current_user, hash_password, verify_password
from app.db import get_db
from app.models.user import User
from app.schemas.user import LoginRequest, PasswordUpdateRequest, RegisterRequest, UserOut
from app.services.seed import ensure_default_categories

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register")
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    exists = db.scalar(select(User).where(User.username == payload.username))
    if exists:
        raise ApiError("手机号已注册")
    user = User(
        username=payload.username,
        password_hash=hash_password(payload.password),
        nickname=payload.nickname or payload.username,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    ensure_default_categories(db, user.id)
    return success(UserOut.model_validate(user).model_dump())


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise ApiError("手机号或密码错误", status_code=401, code=401)
    token = create_access_token(str(user.id))
    return success({"token": token, "token_type": "bearer", "user": UserOut.model_validate(user).model_dump()})


@router.post("/change-password")
def change_password(
    payload: PasswordUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.old_password, current_user.password_hash):
        raise ApiError("原密码错误")
    current_user.password_hash = hash_password(payload.new_password)
    db.commit()
    return success(True)


@router.post("/logout")
def logout():
    return success(True)
