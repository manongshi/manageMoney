from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=6, max_length=128)
    nickname: str | None = Field(default=None, max_length=50)


class LoginRequest(BaseModel):
    username: str
    password: str


class PasswordUpdateRequest(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6, max_length=128)


class UserOut(BaseModel):
    id: int
    username: str
    nickname: str | None = None
    avatar: str | None = None
    gender: int | None = None
    create_time: datetime

    model_config = ConfigDict(from_attributes=True)
