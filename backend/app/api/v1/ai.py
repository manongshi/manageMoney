from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import ApiError
from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.bill import Bill
from app.models.category import Category
from app.models.user import User
from app.schemas.ai import AIParseRequest, AIRecordResult
from app.schemas.bill import BillOut
from app.services.ai_service import parse_bill_text

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/parse")
def parse_bill(payload: AIParseRequest, current_user: User = Depends(get_current_user)):
    _ = current_user
    return success(parse_bill_text(payload.text).model_dump())


@router.post("/record")
def record_bill(
    payload: AIParseRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    parsed = parse_bill_text(payload.text)
    if parsed.amount <= 0:
        raise ApiError("未识别到有效金额")

    category = _match_category(db, current_user.id, parsed.category, parsed.bill_type)
    bill = Bill(
        user_id=current_user.id,
        amount=Decimal(str(parsed.amount)),
        category_id=category.id,
        bill_type=parsed.bill_type,
        remark=parsed.remark,
        bill_time=datetime.now(),
    )
    db.add(bill)
    db.commit()
    db.refresh(bill)
    saved_bill = db.scalar(
        select(Bill)
        .options(joinedload(Bill.category))
        .where(Bill.id == bill.id, Bill.user_id == current_user.id)
    )
    result = AIRecordResult(parsed=parsed, bill=BillOut.model_validate(saved_bill))
    return success(result.model_dump())


def _match_category(db: Session, user_id: int, name: str, bill_type: str) -> Category:
    category = db.scalar(
        select(Category).where(
            Category.user_id == user_id,
            Category.type == bill_type,
            Category.name == name,
        )
    )
    if category:
        return category

    fallback = db.scalar(
        select(Category).where(
            Category.user_id == user_id,
            Category.type == bill_type,
            Category.name == "其他",
        )
    )
    if fallback:
        return fallback

    first_category = db.scalar(
        select(Category)
        .where(Category.user_id == user_id, Category.type == bill_type)
        .order_by(Category.sort_order.asc(), Category.id.asc())
    )
    if first_category is None:
        raise ApiError("请先创建分类")
    return first_category
