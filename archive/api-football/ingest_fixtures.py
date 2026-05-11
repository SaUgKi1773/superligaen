"""
Group 3: Fixture endpoints.
Filter: league_id + season (+ optional date range) → then fixture_id per detail

Fixtures are bulk-inserted. Detail endpoints (events, statistics, lineups,
players, predictions, odds) are then called per finished fixture_id.

Load strategies:
  Initial load  — bulk INSERT all fixtures + INSERT details per finished fixture
  Seasonal load — DELETE by season's fixture_ids + bulk INSERT + INSERT details
  Daily load    — DELETE by fixture_ids in date window + bulk INSERT + INSERT details
"""

import json
import logging

from api import api_get
from config import FIXTURE_DETAIL_ENDPOINTS, FIXTURE_ENDPOINT
from db import FIXTURE_DETAIL_TABLES, FIXTURE_TABLE, _insert

log = logging.getLogger(__name__)


def load_fixtures(conn, league_id: int, season: int,
                  from_date: str | None = None, to_date: str | None = None) -> None:
    """Fetch fixtures and all detail endpoints for finished matches."""
    _, endpoint = FIXTURE_ENDPOINT
    params = {"league": league_id, "season": season}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date

    data = api_get(endpoint, params)
    fixtures = data["response"]
    log.info("League %d season %d: fetched %d fixtures", league_id, season, len(fixtures))

    # Bulk insert fixtures
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany(
        f"INSERT INTO bronze.{FIXTURE_TABLE} (fixture_id, raw_json) VALUES (?, ?)",
        rows,
    )
    log.info("Loaded %d rows into bronze.%s", len(rows), FIXTURE_TABLE)

    # Detail endpoints per finished fixture
    finished = [f for f in fixtures if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")]
    log.info("%d finished fixtures — fetching fixture-level endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            for table, detail_endpoint in FIXTURE_DETAIL_ENDPOINTS:
                _insert(conn, table, ["fixture_id"], [fixture_id],
                        api_get(detail_endpoint, {"fixture": fixture_id})["response"])
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)


def delete_fixture_window(conn, league_id: int, from_date: str, to_date: str | None = None) -> None:
    """Delete fixtures and all detail rows from from_date onwards (or within a window if to_date given)."""
    if to_date:
        query = (
            f"SELECT fixture_id FROM bronze.{FIXTURE_TABLE} "
            "WHERE json_extract_string(raw_json, '$.league.id')::integer = ? "
            "AND json_extract_string(raw_json, '$.fixture.date')::date BETWEEN ?::date AND ?::date"
        )
        params = [league_id, from_date, to_date]
    else:
        query = (
            f"SELECT fixture_id FROM bronze.{FIXTURE_TABLE} "
            "WHERE json_extract_string(raw_json, '$.league.id')::integer = ? "
            "AND json_extract_string(raw_json, '$.fixture.date')::date >= ?::date"
        )
        params = [league_id, from_date]

    fixture_ids = [row[0] for row in conn.execute(query, params).fetchall()]
    if fixture_ids:
        placeholders = ", ".join("?" * len(fixture_ids))
        for table in [FIXTURE_TABLE] + FIXTURE_DETAIL_TABLES:
            conn.execute(
                f"DELETE FROM bronze.{table} WHERE fixture_id IN ({placeholders})",
                fixture_ids,
            )
        log.info("Cleared %d fixtures from the date window for league %d", len(fixture_ids), league_id)
