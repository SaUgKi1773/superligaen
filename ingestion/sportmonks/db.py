"""
DuckDB connection, schema management, and write helpers.

Table categories and their delete strategy
-------------------------------------------
Global    : DELETE FROM table (truncate)      — types, league, seasons, coaches,
                                                transfers, rivals, h2h
Seasonal  : DELETE WHERE _season_id = ?       — stages, rounds, teams, venues,
                                                referees, squads, standings,
                                                topscorers, stage_topscorers,
                                                stage_statistics, round_statistics
Date-win  : DELETE WHERE _fixture_date BETWEEN — fixtures
"""

import json
import logging
import os

import duckdb
from dotenv import load_dotenv

from config import DEFAULT_DB_PATH

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
log = logging.getLogger(__name__)

GLOBAL_TABLES = [
    "sportmonks__types",
    "sportmonks__league",
    "sportmonks__seasons",
    "sportmonks__coaches",
    "sportmonks__transfers",
    "sportmonks__rivals",
    "sportmonks__h2h",
]

SEASONAL_TABLES = [
    "sportmonks__stages",
    "sportmonks__rounds",
    "sportmonks__teams",
    "sportmonks__venues",
    "sportmonks__referees",
    "sportmonks__squads",
    "sportmonks__standings",
    "sportmonks__topscorers",
    "sportmonks__stage_topscorers",
    "sportmonks__stage_statistics",
    "sportmonks__round_statistics",
]

DATE_TABLES = [
    "sportmonks__fixtures",
]

ALL_TABLES = GLOBAL_TABLES + SEASONAL_TABLES + DATE_TABLES


def connect(db_path: str = None) -> duckdb.DuckDBPyConnection:
    path = db_path or os.environ.get("DUCKDB_PATH", DEFAULT_DB_PATH)
    conn = duckdb.connect(path)
    log.info("Connected: %s", path)
    return conn


def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
    """Create bronze schema and all tables; migrate old schemas gracefully."""
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
    for table in ALL_TABLES:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                id            BIGINT,
                raw_json      JSON      NOT NULL,
                _season_id    INTEGER,
                _fixture_date DATE,
                _ingested_at  TIMESTAMP DEFAULT current_timestamp
            )
        """)
        # Migrate: add columns that may be missing from an older schema
        existing = {row[0] for row in conn.execute(f"DESCRIBE bronze.{table}").fetchall()}
        for col, dtype in [("_season_id", "INTEGER"), ("_fixture_date", "DATE")]:
            if col not in existing:
                conn.execute(f"ALTER TABLE bronze.{table} ADD COLUMN {col} {dtype}")
    log.info("Schema verified (%d tables)", len(ALL_TABLES))


# ── Delete helpers ────────────────────────────────────────────────────────────

def delete_global(conn: duckdb.DuckDBPyConnection, table: str) -> int:
    n = conn.execute(f"SELECT COUNT(*) FROM bronze.{table}").fetchone()[0]
    conn.execute(f"DELETE FROM bronze.{table}")
    return n


def delete_by_season(conn: duckdb.DuckDBPyConnection, table: str, season_id: int) -> int:
    n = conn.execute(
        f"SELECT COUNT(*) FROM bronze.{table} WHERE _season_id = ?", [season_id]
    ).fetchone()[0]
    conn.execute(f"DELETE FROM bronze.{table} WHERE _season_id = ?", [season_id])
    return n


def delete_by_date(conn: duckdb.DuckDBPyConnection, table: str,
                   from_date: str, to_date: str) -> int:
    n = conn.execute(
        f"SELECT COUNT(*) FROM bronze.{table} WHERE _fixture_date BETWEEN ? AND ?",
        [from_date, to_date],
    ).fetchone()[0]
    conn.execute(
        f"DELETE FROM bronze.{table} WHERE _fixture_date BETWEEN ? AND ?",
        [from_date, to_date],
    )
    return n


# ── Insert helpers ────────────────────────────────────────────────────────────

def insert_batch(
    conn: duckdb.DuckDBPyConnection,
    table: str,
    rows: list,  # list of (id, raw_json_str, season_id, fixture_date)
) -> None:
    if not rows:
        return
    conn.executemany(
        f"INSERT INTO bronze.{table} (id, raw_json, _season_id, _fixture_date) "
        f"VALUES (?, ?, ?, ?)",
        rows,
    )
