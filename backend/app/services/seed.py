from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.category import Category

DEFAULT_CATEGORIES = [
    ("expense", "餐饮", "restaurant", "#ef4444"),
    ("expense", "交通", "car", "#f97316"),
    ("expense", "购物", "shopping", "#ec4899"),
    ("expense", "娱乐", "game", "#8b5cf6"),
    ("expense", "生活", "home", "#14b8a6"),
    ("expense", "住房", "building", "#64748b"),
    ("expense", "医疗", "medical", "#22c55e"),
    ("expense", "学习", "book", "#3b82f6"),
    ("expense", "旅游", "plane", "#06b6d4"),
    ("expense", "宠物", "pet", "#a855f7"),
    ("expense", "其他", "more", "#6b7280"),
    ("income", "工资", "wallet", "#16a34a"),
    ("income", "奖金", "gift", "#84cc16"),
    ("income", "兼职", "briefcase", "#10b981"),
    ("income", "红包", "red-packet", "#dc2626"),
    ("income", "理财", "chart", "#0ea5e9"),
    ("income", "其他", "more", "#6b7280"),
]


def ensure_default_categories(db: Session, user_id: int) -> None:
    existing = db.scalar(select(Category.id).where(Category.user_id == user_id).limit(1))
    if existing:
        return
    for index, (type_, name, icon, color) in enumerate(DEFAULT_CATEGORIES):
        db.add(
            Category(
                user_id=user_id,
                name=name,
                type=type_,
                icon=icon,
                color=color,
                sort_order=index,
            )
        )
    db.commit()
