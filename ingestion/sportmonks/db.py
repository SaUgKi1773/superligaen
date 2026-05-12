"""
DuckDB connection, schema setup, and upsert helper.
All writes go through upsert() — delete-then-insert on natural key.
"""

import json
import logging
import os

import duckdb
from dotenv import load_dotenv

from config import DEFAULT_DB_PATH

load_dotenv()
log = logging.getLogger(__name__)

BRONZE_TABLES = [
    "sportmonks__seasons",
    "sportmonks__fixtures",
    "sportmonks__standings",
]


def connect() -> duckdb.DuckDBPyConnection:
    path = os.environ.get("DUCKDB_PATH", DEFAULT_DB_PATH)
    conn = duckdb.connect(path)
    log.info("Connected to DuckDB: %s", path)
    return conn


def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
    for table in BRONZE_TABLES:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                id           INTEGER PRIMARY KEY,
                raw_json     JSON        NOT NULL,
                _ingested_at TIMESTAMP   DEFAULT current_timestamp,
                _source      VARCHAR
            )
        """)
    log.info("Bronze schema verified (%d tables)", len(BRONZE_TABLES))


def upsert(conn: duckdb.DuckDBPyConnection, table: str, record_id: int, payload: dict, source: str) -> None:
    conn.execute(f"DELETE FROM bronze.{table} WHERE id = ?", [record_id])
    conn.execute(
        f"INSERT INTO bronze.{table} (id, raw_json, _source) VALUES (?, ?, ?)",
        [record_id, json.dumps(payload), source],
    )
