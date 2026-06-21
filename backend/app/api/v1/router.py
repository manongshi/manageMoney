from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import ai, auth, bill, budget, category, statistics, user

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(user.router)
api_router.include_router(category.router)
api_router.include_router(bill.router)
api_router.include_router(statistics.router)
api_router.include_router(budget.router)
api_router.include_router(ai.router)
