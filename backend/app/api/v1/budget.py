from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.budget import Budget
from app.models.user import User
from app.schemas.budget import BudgetSaveRequest
from app.services.statistics_service import current_month, money, month_bounds, sum_bills

router = APIRouter(prefix="/budget", tags=["budget"])


@router.post("/save")
def save_budget(
    payload: BudgetSaveRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    month = payload.month or current_month()
    budget = db.scalar(select(Budget).where(Budget.user_id == current_user.id, Budget.month == month))
    if budget:
        budget.month_budget = payload.month_budget
    else:
        budget = Budget(user_id=current_user.id, month=month, month_budget=payload.month_budget)
        db.add(budget)
    db.commit()
    return success(_budget_info(db, current_user.id, month, float(payload.month_budget)))


@router.get("/info")
def budget_info(
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    month = month or current_month()
    budget = db.scalar(select(Budget).where(Budget.user_id == current_user.id, Budget.month == month))
    amount = float(budget.month_budget) if budget else 0.0
    return success(_budget_info(db, current_user.id, month, amount))


def _budget_info(db: Session, user_id: int, month: str, amount: float) -> dict[str, float | str | bool]:
    start, end = month_bounds(month)
    spent = sum_bills(db, user_id, "expense", start, end)
    remaining = money(amount - spent)
    percent = round(spent / amount * 100, 2) if amount > 0 else 0.0
    return {
        "month": month,
        "month_budget": money(amount),
        "spent": spent,
        "remaining": remaining,
        "percent": percent,
        "over_budget": spent > amount if amount > 0 else False,
    }
