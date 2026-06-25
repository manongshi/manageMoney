from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))

from scripts.migrate_sqlite_to_mysql import (  # noqa: E402
    TABLE_ORDER,
    MysqlConfig,
    build_mysql_database_url,
    read_sqlite_counts,
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
