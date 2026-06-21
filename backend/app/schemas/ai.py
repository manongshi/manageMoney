from __future__ import annotations

from pydantic import BaseModel, Field


class AIParseRequest(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class AIParseResult(BaseModel):
    amount: float
    category: str
    bill_type: str
    remark: str
    confidence: float
