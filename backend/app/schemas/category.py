from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    type: str = Field(pattern="^(expense|income)$")
    icon: str | None = Field(default=None, max_length=50)
    color: str | None = Field(default=None, max_length=20)
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=50)
    type: str | None = Field(default=None, pattern="^(expense|income)$")
    icon: str | None = Field(default=None, max_length=50)
    color: str | None = Field(default=None, max_length=20)
    sort_order: int | None = None


class CategoryOut(BaseModel):
    id: int
    user_id: int
    name: str
    type: str
    icon: str | None = None
    color: str | None = None
    sort_order: int

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("id", "user_id")
    def serialize_id(self, value: int) -> str:
        return str(value)
