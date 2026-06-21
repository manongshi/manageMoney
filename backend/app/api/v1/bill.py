from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import ApiError
from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.bill import Bill
from app.models.category import Category
from app.models.user import User
from app.schemas.bill import BillCreate, BillOut, BillUpdate

router = APIRouter(prefix="/bill", tags=["bill"])


@router.post("/add")
def add_bill(
    payload: BillCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = _get_category(db, current_user.id, payload.category_id)
    if category.type != payload.bill_type:
        raise ApiError("账单类型与分类类型不一致")
    bill = Bill(
        user_id=current_user.id,
        amount=payload.amount,
        category_id=payload.category_id,
        bill_type=payload.bill_type,
        remark=payload.remark,
        bill_time=payload.bill_time or datetime.now(),
    )
    db.add(bill)
    db.commit()
    db.refresh(bill)
    bill = _get_bill(db, current_user.id, bill.id)
    return success(BillOut.model_validate(bill).model_dump())


@router.put("/update/{bill_id}")
def update_bill(
    bill_id: int,
    payload: BillUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bill = _get_bill(db, current_user.id, bill_id)
    category = _get_category(db, current_user.id, payload.category_id)
    if category.type != payload.bill_type:
        raise ApiError("账单类型与分类类型不一致")
    bill.amount = payload.amount
    bill.category_id = payload.category_id
    bill.bill_type = payload.bill_type
    bill.remark = payload.remark
    bill.bill_time = payload.bill_time or bill.bill_time
    db.commit()
    db.refresh(bill)
    bill = _get_bill(db, current_user.id, bill.id)
    return success(BillOut.model_validate(bill).model_dump())


@router.delete("/delete/{bill_id}")
def delete_bill(
    bill_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bill = _get_bill(db, current_user.id, bill_id)
    db.delete(bill)
    db.commit()
    return success(True)


@router.get("/list")
def list_bills(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=100),
    keyword: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    category_id: int | None = None,
    bill_type: str | None = Query(default=None, pattern="^(expense|income)$"),
    min_amount: float | None = None,
    max_amount: float | None = None,
    order: str = Query(default="bill_time_desc"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = select(Bill).options(joinedload(Bill.category)).where(Bill.user_id == current_user.id)
    if keyword:
        query = query.where(or_(Bill.remark.contains(keyword), Category.name.contains(keyword))).join(Bill.category)
    if start_date:
        query = query.where(Bill.bill_time >= datetime.fromisoformat(start_date))
    if end_date:
        query = query.where(Bill.bill_time <= datetime.fromisoformat(f"{end_date} 23:59:59"))
    if category_id:
        query = query.where(Bill.category_id == category_id)
    if bill_type:
        query = query.where(Bill.bill_type == bill_type)
    if min_amount is not None:
        query = query.where(Bill.amount >= min_amount)
    if max_amount is not None:
        query = query.where(Bill.amount <= max_amount)

    total = db.scalar(select(func.count()).select_from(query.order_by(None).subquery())) or 0
    order_map = {
        "bill_time_asc": Bill.bill_time.asc(),
        "amount_desc": Bill.amount.desc(),
        "amount_asc": Bill.amount.asc(),
    }
    query = query.order_by(order_map.get(order, Bill.bill_time.desc()), Bill.id.desc())
    records = db.scalars(query.offset((page - 1) * page_size).limit(page_size)).all()
    return success({"total": total, "records": [BillOut.model_validate(item).model_dump() for item in records]})


def _get_category(db: Session, user_id: int, category_id: int) -> Category:
    category = db.get(Category, category_id)
    if category is None or category.user_id != user_id:
        raise ApiError("分类不存在", status_code=404, code=404)
    return category


def _get_bill(db: Session, user_id: int, bill_id: int) -> Bill:
    bill = db.scalar(select(Bill).options(joinedload(Bill.category)).where(Bill.id == bill_id))
    if bill is None or bill.user_id != user_id:
        raise ApiError("账单不存在", status_code=404, code=404)
    return bill
