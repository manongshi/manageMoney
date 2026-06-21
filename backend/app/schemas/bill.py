from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.category import CategoryOut


class BillCreate(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    category_id: int
    bill_type: str = Field(pattern="^(expense|income)$")
    remark: str | None = Field(default=None, max_length=255)
    bill_time: datetime | None = None


class BillUpdate(BillCreate):
    pass


class BillOut(BaseModel):
    id: int
    user_id: int
    amount: float
    category_id: int
    bill_type: str
    remark: str | None = None
    bill_time: datetime
    create_time: datetime
    category: CategoryOut

    model_config = ConfigDict(from_attributes=True)
