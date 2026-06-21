from __future__ import annotations

from pydantic import BaseModel

from app.schemas.bill import BillOut


class DayStats(BaseModel):
    income: float
    expense: float
    balance: float


class MonthStats(DayStats):
    month: str


class CategoryStats(BaseModel):
    name: str
    value: float


class TrendPoint(BaseModel):
    label: str
    income: float
    expense: float
    balance: float


class DashboardStats(BaseModel):
    today_income: float
    today_expense: float
    month_income: float
    month_expense: float
    balance: float
    continuous_days: int
    recent_bills: list[BillOut]
    budget_percent: float
