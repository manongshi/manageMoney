from __future__ import annotations

from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.responses import success
from app.core.security import get_current_user
from app.db import get_db
from app.models.bill import Bill
from app.models.budget import Budget
from app.models.category import Category
from app.models.user import User
from app.schemas.bill import BillOut
from app.services.statistics_service import continuous_bill_days, current_month, day_bounds, money, month_bounds, sum_bills

router = APIRouter(prefix="/statistics", tags=["statistics"])


@router.get("/day")
def day_statistics(
    date_value: str | None = Query(default=None, alias="date"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target = date.fromisoformat(date_value) if date_value else date.today()
    start, end = day_bounds(target)
    income = sum_bills(db, current_user.id, "income", start, end)
    expense = sum_bills(db, current_user.id, "expense", start, end)
    return success({"income": income, "expense": expense, "balance": money(income - expense)})


@router.get("/month")
def month_statistics(
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    month = month or current_month()
    start, end = month_bounds(month)
    income = sum_bills(db, current_user.id, "income", start, end)
    expense = sum_bills(db, current_user.id, "expense", start, end)
    return success({"month": month, "income": income, "expense": expense, "balance": money(income - expense)})


@router.get("/category")
def category_statistics(
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    bill_type: str = Query(default="expense", pattern="^(expense|income)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    month = month or current_month()
    start, end = month_bounds(month)
    rows = db.execute(
        select(Category.name, func.coalesce(func.sum(Bill.amount), 0))
        .join(Bill, Bill.category_id == Category.id)
        .where(
            Bill.user_id == current_user.id,
            Bill.bill_type == bill_type,
            Bill.bill_time >= start,
            Bill.bill_time < end,
        )
        .group_by(Category.name)
        .order_by(func.sum(Bill.amount).desc())
    ).all()
    return success([{"name": name, "value": money(value)} for name, value in rows])


@router.get("/trend")
def trend_statistics(
    range_value: str = Query(default="7d", alias="range", pattern="^(7d|30d|12m)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if range_value == "12m":
        today = date.today()
        months = []
        for offset in range(11, -1, -1):
            year = today.year
            month = today.month - offset
            while month <= 0:
                year -= 1
                month += 12
            months.append(f"{year:04d}-{month:02d}")
        data = []
        for month in months:
            start, end = month_bounds(month)
            income = sum_bills(db, current_user.id, "income", start, end)
            expense = sum_bills(db, current_user.id, "expense", start, end)
            data.append({"label": month, "income": income, "expense": expense, "balance": money(income - expense)})
        return success(data)

    days = 7 if range_value == "7d" else 30
    data = []
    for offset in range(days - 1, -1, -1):
        target = date.today() - timedelta(days=offset)
        start, end = day_bounds(target)
        income = sum_bills(db, current_user.id, "income", start, end)
        expense = sum_bills(db, current_user.id, "expense", start, end)
        data.append({"label": target.isoformat(), "income": income, "expense": expense, "balance": money(income - expense)})
    return success(data)


@router.get("/dashboard")
def dashboard_statistics(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today_start, today_end = day_bounds(date.today())
    month = current_month()
    month_start, month_end = month_bounds(month)
    today_income = sum_bills(db, current_user.id, "income", today_start, today_end)
    today_expense = sum_bills(db, current_user.id, "expense", today_start, today_end)
    month_income = sum_bills(db, current_user.id, "income", month_start, month_end)
    month_expense = sum_bills(db, current_user.id, "expense", month_start, month_end)
    budget = db.scalar(select(Budget).where(Budget.user_id == current_user.id, Budget.month == month))
    budget_percent = 0.0
    if budget and float(budget.month_budget) > 0:
        budget_percent = round(month_expense / float(budget.month_budget) * 100, 2)
    recent = db.scalars(
        select(Bill)
        .options(joinedload(Bill.category))
        .where(Bill.user_id == current_user.id)
        .order_by(Bill.bill_time.desc(), Bill.id.desc())
        .limit(5)
    ).all()
    return success(
        {
            "today_income": today_income,
            "today_expense": today_expense,
            "month_income": month_income,
            "month_expense": month_expense,
            "balance": money(month_income - month_expense),
            "continuous_days": continuous_bill_days(db, current_user.id),
            "recent_bills": [BillOut.model_validate(item).model_dump() for item in recent],
            "budget_percent": budget_percent,
        }
    )
