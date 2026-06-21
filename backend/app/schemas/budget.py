from __future__ import annotations

from decimal import Decimal

from pydantic import BaseModel, Field


class BudgetSaveRequest(BaseModel):
    month: str | None = Field(default=None, pattern=r"^\d{4}-\d{2}$")
    month_budget: Decimal = Field(ge=0, max_digits=10, decimal_places=2)


class BudgetOut(BaseModel):
    month: str
    month_budget: float
    spent: float
    remaining: float
    percent: float
    over_budget: bool
