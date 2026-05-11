"""
Fixture ingestion — two phases:

Phase A (fixture list):
  load_fixtures_for_season()     — paginate /fixtures?filters=fixtureSeasons:{id}
  load_fixtures_for_date_range() — /fixtures/between/{from}/{to}?filters=fixtureLeagues:{id}

  Stores core fixture fields + participants + scores + state per fixture_id in
  bronze.sportmonks__fixtures.

Phase B (fixture detail):
  load_fixture_details()  — one call per fixture_id
  GET /fixtures/{id}?include=events;statistics;lineups;referees

  Extracts each include into its own bronze table (one JSON array per fixture_id).
  Only ingests fixtures where state=FT (full time) or NS (not started, for future fixtures).
"""

import logging
from typing import Sequence

import duckdb

from api import api_get, api_get_all
from config import FIXTURE_INCLUDES, LEAGUE_ID, TBL_FIXTURE_EVENTS, TBL_FIXTURE_LINEUPS, TBL_FIXTURE_REFEREES, TBL_FIXTURE_STATS, TBL_FIXTURES
from db import upsert

log = logging.getLogger(__name__)

# States worth fetching detail for (FT=5, NS=1, LIVE states 2-4,6,7)
_FINISHED_STATE = 5


def load_fixtures_for_season(conn: duckdb.DuckDBPyConnection, season_id: int) -> list[int]:
    """Load all fixtures for a season. Returns list of fixture_ids."""
    log.info("Loading fixtures for season %d", season_id)
    fixture_ids = []
    for page in api_get_all("fixtures", params={"filters": f"fixtureSeasons:{season_id}", "include": "participants;scores;state"}):
        for fixture in page.get("data", []):
            _store_fixture(conn, fixture)
            fixture_ids.append(fixture["id"])
    log.info("Fixtures: %d for season %d", len(fixture_ids), season_id)
    return fixture_ids


def load_fixtures_for_date_range(conn: duckdb.DuckDBPyConnection, from_date: str, to_date: str) -> list[int]:
    """Load fixtures in a date range. Returns list of fixture_ids."""
    log.info("Loading fixtures %s → %s", from_date, to_date)
    fixture_ids = []
    endpoint = f"fixtures/between/{from_date}/{to_date}"
    for page in api_get_all(endpoint, params={"filters": f"fixtureLeagues:{LEAGUE_ID}", "include": "participants;scores;state"}):
        for fixture in page.get("data", []):
            _store_fixture(conn, fixture)
            fixture_ids.append(fixture["id"])
    log.info("Fixtures: %d in range %s → %s", len(fixture_ids), from_date, to_date)
    return fixture_ids


def load_fixture_details(conn: duckdb.DuckDBPyConnection, fixture_ids: Sequence[int]) -> None:
    """Fetch detail includes for a list of fixture IDs. Skips non-finished fixtures."""
    finished = _get_finished_fixture_ids(conn, fixture_ids)
    log.info("Loading detail for %d finished fixtures (of %d total)", len(finished), len(fixture_ids))

    for fixture_id in finished:
        data = api_get(f"fixtures/{fixture_id}", params={"include": FIXTURE_INCLUDES})
        fixture = data.get("data", {})
        upsert(conn, TBL_FIXTURE_EVENTS,   ["fixture_id"], [fixture_id], fixture.get("events", []))
        upsert(conn, TBL_FIXTURE_STATS,    ["fixture_id"], [fixture_id], fixture.get("statistics", []))
        upsert(conn, TBL_FIXTURE_LINEUPS,  ["fixture_id"], [fixture_id], fixture.get("lineups", []))
        upsert(conn, TBL_FIXTURE_REFEREES, ["fixture_id"], [fixture_id], fixture.get("referees", []))

    log.info("Fixture detail load complete")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _store_fixture(conn: duckdb.DuckDBPyConnection, fixture: dict) -> None:
    """Strip detail includes from fixture dict and store core fields."""
    core = {k: v for k, v in fixture.items() if k not in ("events", "statistics", "lineups", "referees")}
    upsert(conn, TBL_FIXTURES, ["fixture_id"], [fixture["id"]], core)


def _get_finished_fixture_ids(conn: duckdb.DuckDBPyConnection, fixture_ids: Sequence[int]) -> list[int]:
    """Filter to only fixture_ids where state_id = 5 (FT)."""
    if not fixture_ids:
        return []
    placeholders = ", ".join("?" * len(fixture_ids))
    rows = conn.execute(
        f"SELECT fixture_id FROM bronze.{TBL_FIXTURES} "
        f"WHERE fixture_id IN ({placeholders}) AND (raw_json->>'$.state_id')::integer = {_FINISHED_STATE}",
        list(fixture_ids),
    ).fetchall()
    return [r[0] for r in rows]
