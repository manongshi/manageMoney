from __future__ import annotations

import argparse
import os
import re
import sqlite3
import sys
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import Engine

TABLE_ORDER = ("users", "categories", "bills", "budgets")
DEFAULT_SQLITE_PATH = Path(__file__).resolve().parents[1] / "ai_account_book.db"
IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9_]+$")


@dataclass(frozen=True)
class MysqlConfig:
    host: str
    port: int
    user: str
    password: str
    database: str


@dataclass
class IdMaps:
    users: dict[int, int] = field(default_factory=dict)
    categories: dict[int, int] = field(default_factory=dict)
    bills: dict[int, int] = field(default_factory=dict)
    budgets: dict[int, int] = field(default_factory=dict)


def quote_mysql_identifier(name: str) -> str:
    if not IDENTIFIER_RE.fullmatch(name):
        raise ValueError(f"Unsafe MySQL identifier: {name}")
    return f"`{name}`"


def quote_sqlite_identifier(name: str) -> str:
    if not IDENTIFIER_RE.fullmatch(name):
        raise ValueError(f"Unsafe SQLite identifier: {name}")
    return f'"{name}"'


def build_mysql_database_url(config: MysqlConfig) -> str:
    user = quote(config.user, safe="")
    password = quote(config.password, safe="")
    database = quote(config.database, safe="")
    return f"mysql+pymysql://{user}:{password}@{config.host}:{config.port}/{database}?charset=utf8mb4"


def ensure_backend_path() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    backend_root_text = str(backend_root)
    if backend_root_text not in sys.path:
        sys.path.insert(0, backend_root_text)


def next_snowflake_id() -> int:
    ensure_backend_path()
    from app.core.snowflake import generate_snowflake_id

    return generate_snowflake_id()


def read_sqlite_counts(sqlite_path: Path, tables: tuple[str, ...] = TABLE_ORDER) -> dict[str, int]:
    if not sqlite_path.exists():
        raise FileNotFoundError(f"SQLite database does not exist: {sqlite_path}")

    connection = sqlite3.connect(sqlite_path)
    try:
        return {
            table_name: int(
                connection.execute(
                    f"SELECT COUNT(*) FROM {quote_sqlite_identifier(table_name)}"
                ).fetchone()[0]
            )
            for table_name in tables
        }
    finally:
        connection.close()


def read_mysql_counts(engine: Engine, tables: tuple[str, ...] = TABLE_ORDER) -> dict[str, int]:
    existing_tables = set(inspect(engine).get_table_names())
    counts: dict[str, int] = {}
    with engine.connect() as connection:
        for table_name in tables:
            if table_name not in existing_tables:
                counts[table_name] = 0
                continue
            counts[table_name] = int(
                connection.execute(
                    text(f"SELECT COUNT(*) FROM {quote_mysql_identifier(table_name)}")
                ).scalar_one()
            )
    return counts


def create_mysql_database(config: MysqlConfig) -> None:
    try:
        import pymysql
    except ImportError as exc:
        raise RuntimeError("PyMySQL is required. Install backend requirements first.") from exc

    connection = pymysql.connect(
        host=config.host,
        port=config.port,
        user=config.user,
        password=config.password,
        charset="utf8mb4",
        autocommit=True,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "CREATE DATABASE IF NOT EXISTS "
                f"{quote_mysql_identifier(config.database)} "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
    finally:
        connection.close()


def load_metadata(database_url: str):
    ensure_backend_path()
    os.environ["DATABASE_URL"] = database_url

    import app.models  # noqa: F401
    from app.db import Base

    return Base.metadata


def sqlite_columns(connection: sqlite3.Connection, table_name: str) -> list[str]:
    rows = connection.execute(f"PRAGMA table_info({quote_sqlite_identifier(table_name)})").fetchall()
    return [str(row[1]) for row in rows]


def rewrite_row_ids(
    table_name: str,
    row: dict,
    id_maps: IdMaps,
    id_generator: Callable[[], int],
) -> dict:
    rewritten = dict(row)
    old_id = int(rewritten["id"])
    new_id = id_generator()
    rewritten["id"] = new_id

    if table_name == "users":
        id_maps.users[old_id] = new_id
        return rewritten

    if table_name == "categories":
        rewritten["user_id"] = id_maps.users[int(rewritten["user_id"])]
        id_maps.categories[old_id] = new_id
        return rewritten

    if table_name == "bills":
        rewritten["user_id"] = id_maps.users[int(rewritten["user_id"])]
        rewritten["category_id"] = id_maps.categories[int(rewritten["category_id"])]
        id_maps.bills[old_id] = new_id
        return rewritten

    if table_name == "budgets":
        rewritten["user_id"] = id_maps.users[int(rewritten["user_id"])]
        id_maps.budgets[old_id] = new_id
        return rewritten

    raise ValueError(f"Unsupported table for id rewrite: {table_name}")


def copy_table_rows(
    sqlite_connection: sqlite3.Connection,
    mysql_connection,
    table_name: str,
    id_maps: IdMaps,
    regenerate_ids: bool,
    id_generator: Callable[[], int],
) -> int:
    columns = sqlite_columns(sqlite_connection, table_name)
    if not columns:
        raise RuntimeError(f"SQLite table has no columns: {table_name}")

    sqlite_column_sql = ", ".join(quote_sqlite_identifier(column) for column in columns)
    mysql_column_sql = ", ".join(quote_mysql_identifier(column) for column in columns)
    value_sql = ", ".join(f":{column}" for column in columns)

    rows = sqlite_connection.execute(
        f"SELECT {sqlite_column_sql} FROM {quote_sqlite_identifier(table_name)} ORDER BY id"
    ).fetchall()
    if not rows:
        return 0
    row_payloads = [
        rewrite_row_ids(table_name, dict(row), id_maps, id_generator) if regenerate_ids else dict(row)
        for row in rows
    ]

    mysql_connection.execute(
        text(
            f"INSERT INTO {quote_mysql_identifier(table_name)} "
            f"({mysql_column_sql}) VALUES ({value_sql})"
        ),
        row_payloads,
    )
    return len(rows)


def copy_sqlite_to_mysql(
    sqlite_path: Path,
    target_engine: Engine,
    regenerate_ids: bool = False,
    id_generator: Callable[[], int] = next_snowflake_id,
) -> dict[str, int]:
    sqlite_connection = sqlite3.connect(sqlite_path)
    sqlite_connection.row_factory = sqlite3.Row
    try:
        copied_counts: dict[str, int] = {}
        id_maps = IdMaps()
        with target_engine.begin() as mysql_connection:
            for table_name in TABLE_ORDER:
                copied_counts[table_name] = copy_table_rows(
                    sqlite_connection,
                    mysql_connection,
                    table_name,
                    id_maps,
                    regenerate_ids,
                    id_generator,
                )
        return copied_counts
    finally:
        sqlite_connection.close()


def mysql_config_from_args(args: argparse.Namespace) -> MysqlConfig:
    password = args.mysql_password or os.getenv("MYSQL_PASSWORD", "")
    if not password:
        raise SystemExit("MYSQL_PASSWORD is required. Set it in the environment or pass --mysql-password.")

    return MysqlConfig(
        host=args.mysql_host,
        port=args.mysql_port,
        user=args.mysql_user,
        password=password,
        database=args.mysql_database,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migrate the local SQLite data to MySQL.")
    parser.add_argument("--sqlite-path", type=Path, default=DEFAULT_SQLITE_PATH)
    parser.add_argument("--mysql-host", default=os.getenv("MYSQL_HOST", "127.0.0.1"))
    parser.add_argument("--mysql-port", type=int, default=int(os.getenv("MYSQL_PORT", "3306")))
    parser.add_argument("--mysql-user", default=os.getenv("MYSQL_USER", "root"))
    parser.add_argument("--mysql-password", default=None)
    parser.add_argument("--mysql-database", default=os.getenv("MYSQL_DATABASE", "ai_account_book"))
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Drop and recreate the target app tables before copying data.",
    )
    parser.add_argument(
        "--regenerate-ids",
        action="store_true",
        help="Generate fresh snowflake IDs and rewrite foreign keys while copying data.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sqlite_path = args.sqlite_path.resolve()
    config = mysql_config_from_args(args)
    database_url = build_mysql_database_url(config)

    sqlite_counts = read_sqlite_counts(sqlite_path)
    create_mysql_database(config)

    metadata = load_metadata(database_url)
    target_engine = create_engine(database_url, future=True)

    existing_counts = read_mysql_counts(target_engine)
    if any(existing_counts.values()) and not args.replace:
        raise SystemExit(
            "Target MySQL tables already contain data. "
            "Run with --replace if you want to overwrite them. "
            f"Current counts: {existing_counts}"
        )

    if args.replace:
        metadata.drop_all(bind=target_engine)
    metadata.create_all(bind=target_engine)

    copied_counts = copy_sqlite_to_mysql(sqlite_path, target_engine, regenerate_ids=args.regenerate_ids)
    final_counts = read_mysql_counts(target_engine)

    print(f"SQLite counts: {sqlite_counts}")
    print(f"Regenerated IDs: {args.regenerate_ids}")
    print(f"Copied counts: {copied_counts}")
    print(f"MySQL counts: {final_counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
