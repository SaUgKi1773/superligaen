"""
Season-level data ingestion.

Endpoints:
  load_standings   — /standings/seasons/{id}?include=details
  load_topscorers  — /topscorers/seasons/{id}

Both store the full paginated response as a single JSON array per season_id.
Safe to re-run (upsert by season_id).
"""

import logging

import duckdb

from api import api_get_all
from config import TBL_STANDINGS, TBL_TOPSCORERS
from db import upsert

log = logging.getLogger(__name__)


def load_standings(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading standings for season %d", season_id)
    rows = []
    for page in api_get_all(f"standings/seasons/{season_id}", params={"include": "details"}):
        rows.extend(page.get("data", []))
    upsert(conn, TBL_STANDINGS, ["season_id"], [season_id], rows)
    log.info("Standings: %d rows for season %d", len(rows), season_id)


def load_topscorers(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading topscorers for season %d", season_id)
    rows = []
    for page in api_get_all(f"topscorers/seasons/{season_id}"):
        rows.extend(page.get("data", []))
    upsert(conn, TBL_TOPSCORERS, ["season_id"], [season_id], rows)
    log.info("Topscorers: %d rows for season %d", len(rows), season_id)
