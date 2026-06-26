from __future__ import annotations

from datetime import date, datetime, time, timedelta
from decimal import Decimal

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.models.bill import Bill


def money(value: Decimal | int | float | None) -> float:
    return round(float(value or 0), 2)


def day_bounds(target_date: date) -> tuple[datetime, datetime]:
    return datetime.combine(target_date, time.min), datetime.combine(target_date, time.max)


def month_bounds(month: str) -> tuple[datetime, datetime]:
    year, month_num = [int(part) for part in month.split("-")]
    start = datetime(year, month_num, 1)
    if month_num == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month_num + 1, 1)
    return start, end


def current_month() -> str:
    return date.today().strftime("%Y-%m")


def sum_bills(db: Session, user_id: int, bill_type: str, start: datetime, end: datetime) -> float:
    result = db.scalar(
        select(func.coalesce(func.sum(Bill.amount), 0)).where(
            Bill.user_id == user_id,
            Bill.bill_type == bill_type,
            Bill.bill_time >= start,
            Bill.bill_time < end,
        )
    )
    return money(result)


def bill_base_query(user_id: int) -> Select[tuple[Bill]]:
    return select(Bill).where(Bill.user_id == user_id)


def continuous_bill_days(db: Session, user_id: int) -> int:
    rows = db.execute(
        select(func.date(Bill.bill_time)).where(Bill.user_id == user_id).group_by(func.date(Bill.bill_time))
    ).all()
    days = {_coerce_date(row[0]) for row in rows if row[0]}
    cursor = date.today()
    count = 0
    while cursor in days:
        count += 1
        cursor -= timedelta(days=1)
    return count


def _coerce_date(value) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))
