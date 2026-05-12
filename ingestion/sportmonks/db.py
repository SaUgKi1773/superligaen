"""
Database connection and schema management for the Sportmonks bronze layer.

Two targets:
  local  — local_dev.duckdb at the repo root
  prod   — MotherDuck (md:superligaen)

Write helpers:
  upsert()    — insert or replace by primary key (idempotent, used by all loaders)
  truncate()  — delete all rows (used by full-refresh runs)
"""

import json
import logging
import os
from pathlib import Path

import duckdb
from dotenv import load_dotenv

from config import (
    ALL_TABLES,
    FIXTURE_TABLES,
    SEASON_TABLES,
    STATIC_TABLES,
    TBL_FIXTURES,
    TBL_FIXTURE_EVENTS,
    TBL_FIXTURE_LINEUPS,
    TBL_FIXTURE_REFEREES,
    TBL_FIXTURE_STATS,
    TBL_LEAGUES,
    TBL_REFEREES,
    TBL_ROUNDS,
    TBL_SEASONS,
    TBL_STANDINGS,
    TBL_TEAMS,
    TBL_TOPSCORERS,
    TBL_VENUES,
)

load_dotenv()
log = logging.getLogger(__name__)

_REPO_ROOT = Path(__file__).resolve().parents[2]
_LOCAL_DB  = _REPO_ROOT / "local_dev.duckdb"


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def connect(target: str = "local") -> duckdb.DuckDBPyConnection:
    if target == "local":
        conn = duckdb.connect(str(_LOCAL_DB))
        log.info("Connected to local DuckDB: %s", _LOCAL_DB)
    elif target == "prod":
        token = os.environ.get("MOTHERDUCK_TOKEN")
        if not token:
            raise RuntimeError("MOTHERDUCK_TOKEN env var is not set")
        conn = duckdb.connect(f"md:superligaen?motherduck_token={token}")
        log.info("Connected to MotherDuck: superligaen")
    else:
        raise ValueError(f"Unknown target '{target}' — use 'local' or 'prod'")
    return conn


# ---------------------------------------------------------------------------
# Schema setup
# ---------------------------------------------------------------------------

def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")

    # league_id PK
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_LEAGUES} (
            league_id   INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # season_id PK
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_SEASONS} (
            season_id   INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # (season_id, team_id) PK — teams roster changes each season
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_TEAMS} (
            season_id   INTEGER,
            team_id     INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season_id, team_id)
        )
    """)

    # venue_id PK
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_VENUES} (
            venue_id    INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # (season_id, referee_id) PK — referee roster changes each season
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_REFEREES} (
            season_id   INTEGER,
            referee_id  INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season_id, referee_id)
        )
    """)

    # (season_id, round_id) PK — rounds are season-specific
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_ROUNDS} (
            season_id   INTEGER,
            round_id    INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season_id, round_id)
        )
    """)

    # season_id PK (full JSON array with details included)
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_STANDINGS} (
            season_id   INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # season_id PK
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_TOPSCORERS} (
            season_id   INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # fixture_id PK — core fixture fields + participants + scores + state
    conn.execute(f"""
        CREATE TABLE IF NOT EXISTS bronze.{TBL_FIXTURES} (
            fixture_id  INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)

    # fixture_id PK — one row per fixture, raw JSON array of events
    for tbl in [TBL_FIXTURE_EVENTS, TBL_FIXTURE_STATS, TBL_FIXTURE_LINEUPS, TBL_FIXTURE_REFEREES]:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{tbl} (
                fixture_id  INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    log.info("Bronze schema verified — %d tables", len(ALL_TABLES))


# ---------------------------------------------------------------------------
# Write helpers
# ---------------------------------------------------------------------------

def upsert(conn: duckdb.DuckDBPyConnection, table: str, key_cols: list[str], key_vals: list, payload) -> None:
    """Delete existing row(s) by key then insert. Idempotent."""
    where = " AND ".join(f"{col} = ?" for col in key_cols)
    conn.execute(f"DELETE FROM bronze.{table} WHERE {where}", key_vals)
    cols = ", ".join(key_cols) + ", raw_json"
    placeholders = ", ".join(["?"] * len(key_vals)) + ", ?"
    conn.execute(
        f"INSERT INTO bronze.{table} ({cols}) VALUES ({placeholders})",
        key_vals + [json.dumps(payload)],
    )


# ---------------------------------------------------------------------------
# Bulk helpers
# ---------------------------------------------------------------------------

def truncate_all(conn: duckdb.DuckDBPyConnection) -> None:
    for table in ALL_TABLES:
        conn.execute(f"DELETE FROM bronze.{table}")
    log.info("All %d bronze tables truncated", len(ALL_TABLES))


def delete_fixtures_for_season(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    """Remove all fixture-level rows for a given season across all fixture tables."""
    fixture_ids = [
        row[0] for row in conn.execute(
            f"SELECT fixture_id FROM bronze.{TBL_FIXTURES} "
            "WHERE raw_json->>'$.season_id' = ?",
            [str(season_id)],
        ).fetchall()
    ]
    if not fixture_ids:
        return
    placeholders = ", ".join("?" * len(fixture_ids))
    for tbl in FIXTURE_TABLES:
        conn.execute(f"DELETE FROM bronze.{tbl} WHERE fixture_id IN ({placeholders})", fixture_ids)
    log.info("Season %d: removed %d fixtures from bronze", season_id, len(fixture_ids))


def get_current_season_id(conn: duckdb.DuckDBPyConnection) -> int:
    """Read the current season_id from bronze.sportmonks__seasons."""
    row = conn.execute(
        f"SELECT season_id FROM bronze.{TBL_SEASONS} WHERE raw_json->>'$.is_current' = 'true' LIMIT 1"
    ).fetchone()
    if row:
        return row[0]
    raise RuntimeError(
        "Current season not found in bronze — run a full load first."
    )
