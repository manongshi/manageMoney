from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

from scripts.migrate_sqlite_to_mysql import (  # noqa: E402
    IdMaps,
    TABLE_ORDER,
    MysqlConfig,
    build_mysql_database_url,
    read_sqlite_counts,
    rewrite_row_ids,
)


def test_build_mysql_database_url_escapes_credentials():
    config = MysqlConfig(
        host="127.0.0.1",
        port=3306,
        user="root",
        password="pa ss/word",
        database="ai_account_book",
    )

    assert (
        build_mysql_database_url(config)
        == "mysql+pymysql://root:pa%20ss%2Fword@127.0.0.1:3306/ai_account_book?charset=utf8mb4"
    )


def test_read_sqlite_counts_reports_required_tables(tmp_path):
    sqlite_path = tmp_path / "book.db"
    connection = sqlite3.connect(sqlite_path)
    try:
        for table_name in TABLE_ORDER:
            connection.execute(f"CREATE TABLE {table_name} (id INTEGER PRIMARY KEY)")
        connection.executemany("INSERT INTO users (id) VALUES (?)", [(1,), (2,)])
        connection.execute("INSERT INTO categories (id) VALUES (1)")
        connection.execute("INSERT INTO bills (id) VALUES (1)")
        connection.commit()
    finally:
        connection.close()

    assert read_sqlite_counts(sqlite_path) == {
        "users": 2,
        "categories": 1,
        "bills": 1,
        "budgets": 0,
    }


def test_rewrite_row_ids_regenerates_foreign_keys():
    ids = iter([101, 201, 301, 401])
    id_maps = IdMaps()
    next_id = lambda: next(ids)

    user = rewrite_row_ids("users", {"id": 1, "username": "u"}, id_maps, next_id)
    category = rewrite_row_ids("categories", {"id": 2, "user_id": 1}, id_maps, next_id)
    bill = rewrite_row_ids(
        "bills",
        {"id": 3, "user_id": 1, "category_id": 2},
        id_maps,
        next_id,
    )
    budget = rewrite_row_ids("budgets", {"id": 4, "user_id": 1}, id_maps, next_id)

    assert user["id"] == 101
    assert category == {"id": 201, "user_id": 101}
    assert bill == {"id": 301, "user_id": 101, "category_id": 201}
    assert budget == {"id": 401, "user_id": 101}
