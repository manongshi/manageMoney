from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

os.environ["DATABASE_URL"] = "sqlite:///./test_ai_account_book.db"
os.environ["SECRET_KEY"] = "test-secret"

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models.bill import Bill  # noqa: E402
from app.models.budget import Budget  # noqa: E402
from app.models.category import Category  # noqa: E402
from app.models.user import User  # noqa: E402


MIN_SNOWFLAKE_ID = 10_000_000_000_000


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client():
    return TestClient(app)


def assert_success(response, code=200):
    assert response.status_code == code
    body = response.json()
    assert body["code"] == 200
    assert body["msg"] == "success"
    return body["data"]


def login_headers(client: TestClient) -> dict[str, str]:
    register_data = assert_success(
        client.post(
            "/auth/register",
            json={
                "username": "13800000000",
                "password": "secret123",
                "nickname": "测试用户",
            },
        )
    )
    assert register_data["username"] == "13800000000"

    login_data = assert_success(
        client.post(
            "/auth/login",
            json={"username": "13800000000", "password": "secret123"},
        )
    )
    assert login_data["token"]
    return {"Authorization": f"Bearer {login_data['token']}"}


def assert_api_snowflake_id(value):
    assert isinstance(value, str)
    assert int(value) >= MIN_SNOWFLAKE_ID


def assert_db_snowflake_ids(values):
    assert values
    assert all(isinstance(value, int) for value in values)
    assert all(value >= MIN_SNOWFLAKE_ID for value in values)


def test_created_database_records_use_snowflake_ids(client: TestClient):
    headers = login_headers(client)

    profile = assert_success(client.get("/user/me", headers=headers))
    assert_api_snowflake_id(profile["id"])

    categories = assert_success(client.get("/category/list?type=expense", headers=headers))
    assert categories
    for category in categories:
        assert_api_snowflake_id(category["id"])
        assert category["user_id"] == profile["id"]

    food_id = categories[0]["id"]
    bill = assert_success(
        client.post(
            "/bill/add",
            headers=headers,
            json={
                "amount": 20,
                "category_id": food_id,
                "bill_type": "expense",
                "remark": "snowflake-id-check",
            },
        )
    )
    assert_api_snowflake_id(bill["id"])
    assert bill["user_id"] == profile["id"]
    assert bill["category_id"] == food_id

    assert_success(
        client.post(
            "/budget/save",
            headers=headers,
            json={"month": "2026-06", "month_budget": 3000},
        )
    )

    with SessionLocal() as db:
        assert_db_snowflake_ids(db.scalars(select(User.id)).all())
        assert_db_snowflake_ids(db.scalars(select(Category.id)).all())
        assert_db_snowflake_ids(db.scalars(select(Bill.id)).all())
        assert_db_snowflake_ids(db.scalars(select(Budget.id)).all())


def test_register_login_profile_and_default_categories(client: TestClient):
    headers = login_headers(client)

    profile = assert_success(client.get("/user/me", headers=headers))
    assert profile["username"] == "13800000000"
    assert profile["nickname"] == "测试用户"

    categories = assert_success(client.get("/category/list", headers=headers))
    names = {item["name"] for item in categories}
    assert {"餐饮", "交通", "工资", "理财", "其他"}.issubset(names)


def test_bill_crud_and_filters(client: TestClient):
    headers = login_headers(client)
    categories = assert_success(client.get("/category/list?type=expense", headers=headers))
    food_id = next(item["id"] for item in categories if item["name"] == "餐饮")

    added = assert_success(
        client.post(
            "/bill/add",
            headers=headers,
            json={
                "amount": 20,
                "category_id": food_id,
                "bill_type": "expense",
                "remark": "午饭",
            },
        )
    )
    assert added["amount"] == 20.0
    assert added["category"]["name"] == "餐饮"

    listed = assert_success(client.get("/bill/list?keyword=午饭", headers=headers))
    assert listed["total"] == 1
    assert listed["records"][0]["remark"] == "午饭"

    updated = assert_success(
        client.put(
            f"/bill/update/{added['id']}",
            headers=headers,
            json={
                "amount": 25,
                "category_id": food_id,
                "bill_type": "expense",
                "remark": "午饭加饮料",
            },
        )
    )
    assert updated["amount"] == 25.0
    assert updated["remark"] == "午饭加饮料"

    assert_success(client.delete(f"/bill/delete/{added['id']}", headers=headers))
    empty = assert_success(client.get("/bill/list", headers=headers))
    assert empty["total"] == 0


def test_statistics_budget_and_ai_parse(client: TestClient):
    headers = login_headers(client)
    categories = assert_success(client.get("/category/list", headers=headers))
    food_id = next(item["id"] for item in categories if item["name"] == "餐饮")
    salary_id = next(item["id"] for item in categories if item["name"] == "工资")

    assert_success(
        client.post(
            "/bill/add",
            headers=headers,
            json={
                "amount": 30,
                "category_id": food_id,
                "bill_type": "expense",
                "remark": "晚饭",
            },
        )
    )
    assert_success(
        client.post(
            "/bill/add",
            headers=headers,
            json={
                "amount": 8000,
                "category_id": salary_id,
                "bill_type": "income",
                "remark": "工资",
            },
        )
    )

    today = date.today().isoformat()
    month = today[:7]

    day_stats = assert_success(client.get(f"/statistics/day?date={today}", headers=headers))
    assert day_stats == {"income": 8000.0, "expense": 30.0, "balance": 7970.0}

    month_stats = assert_success(client.get(f"/statistics/month?month={month}", headers=headers))
    assert month_stats["month"] == month
    assert month_stats["income"] == 8000.0
    assert month_stats["expense"] == 30.0
    assert month_stats["balance"] == 7970.0

    category_stats = assert_success(
        client.get(f"/statistics/category?month={month}&bill_type=expense", headers=headers)
    )
    assert category_stats == [{"name": "餐饮", "value": 30.0}]

    budget = assert_success(
        client.post(
            "/budget/save",
            headers=headers,
            json={"month": month, "month_budget": 3000},
        )
    )
    assert budget["month_budget"] == 3000.0

    budget_info = assert_success(client.get(f"/budget/info?month={month}", headers=headers))
    assert budget_info["spent"] == 30.0
    assert budget_info["remaining"] == 2970.0
    assert budget_info["percent"] == 1.0

    dashboard = assert_success(client.get("/statistics/dashboard", headers=headers))
    assert dashboard["month_income"] == 8000.0
    assert dashboard["month_expense"] == 30.0
    assert dashboard["budget_percent"] == 1.0
    assert len(dashboard["recent_bills"]) == 2

    parsed = assert_success(
        client.post(
            "/ai/parse",
            headers=headers,
            json={"text": "今天中午吃麻辣烫花了25块"},
        )
    )
    assert parsed["amount"] == 25.0
    assert parsed["category"] == "餐饮"
    assert parsed["bill_type"] == "expense"
    assert parsed["remark"] == "麻辣烫"

    recorded = assert_success(
        client.post(
            "/ai/record",
            headers=headers,
            json={"text": "今天中午吃麻辣烫花了25块"},
        )
    )
    assert recorded["parsed"]["amount"] == 25.0
    assert recorded["parsed"]["category"] == "餐饮"
    assert recorded["bill"]["amount"] == 25.0
    assert recorded["bill"]["category"]["name"] == "餐饮"
    assert recorded["bill"]["bill_type"] == "expense"

    dashboard = assert_success(client.get("/statistics/dashboard", headers=headers))
    assert dashboard["month_expense"] == 55.0
    assert len(dashboard["recent_bills"]) == 3
