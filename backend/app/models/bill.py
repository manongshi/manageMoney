from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.snowflake import generate_snowflake_id
from app.db import Base


class Bill(Base):
    __tablename__ = "bills"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
        index=True,
        default=generate_snowflake_id,
        autoincrement=False,
    )
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    category_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("categories.id"), index=True)
    bill_type: Mapped[str] = mapped_column(String(20), index=True)
    remark: Mapped[str | None] = mapped_column(String(255), nullable=True)
    bill_time: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, index=True)
    create_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="bills")
    category = relationship("Category", back_populates="bills")
