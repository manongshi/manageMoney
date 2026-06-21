from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.responses import success
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.ai import AIParseRequest
from app.services.ai_service import parse_bill_text

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/parse")
def parse_bill(payload: AIParseRequest, current_user: User = Depends(get_current_user)):
    _ = current_user
    return success(parse_bill_text(payload.text).model_dump())
