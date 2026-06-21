from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.responses import success
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.user import UserOut

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return success(UserOut.model_validate(current_user).model_dump())
