from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import ApiError
from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.bill import Bill
from app.models.category import Category
from app.models.user import User
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate
from app.services.seed import ensure_default_categories

router = APIRouter(prefix="/category", tags=["category"])


@router.get("/list")
def list_categories(
    type: str | None = Query(default=None, pattern="^(expense|income)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ensure_default_categories(db, current_user.id)
    query = select(Category).where(Category.user_id == current_user.id)
    if type:
        query = query.where(Category.type == type)
    query = query.order_by(Category.type, Category.sort_order, Category.id)
    categories = db.scalars(query).all()
    return success([CategoryOut.model_validate(item).model_dump() for item in categories])


@router.post("/add")
def add_category(
    payload: CategoryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = Category(user_id=current_user.id, **payload.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return success(CategoryOut.model_validate(category).model_dump())


@router.put("/update/{category_id}")
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = _get_category(db, current_user.id, category_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, key, value)
    db.commit()
    db.refresh(category)
    return success(CategoryOut.model_validate(category).model_dump())


@router.delete("/delete/{category_id}")
def delete_category(
    category_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = _get_category(db, current_user.id, category_id)
    used = db.scalar(select(Bill.id).where(Bill.category_id == category.id).limit(1))
    if used:
        raise ApiError("分类已有账单，不能删除")
    db.delete(category)
    db.commit()
    return success(True)


def _get_category(db: Session, user_id: int, category_id: int) -> Category:
    category = db.get(Category, category_id)
    if category is None or category.user_id != user_id:
        raise ApiError("分类不存在", status_code=404, code=404)
    return category
