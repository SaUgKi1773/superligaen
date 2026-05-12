"""
Sportmonks bronze ingestion entry point.

Usage:
  python run.py                # incremental — last 3 days + 4 weeks ahead
  python run.py --full-load    # full historical load from 2010/2011 onwards

Run from the ingestion/sportmonks/ directory, or set DUCKDB_PATH explicitly.

Adding a new endpoint
---------------------
1. Add the table name to db.py BRONZE_TABLES.
2. Drop one line into the right endpoint list below (SEASON_ENDPOINTS,
   STAGE_ENDPOINTS, ROUND_ENDPOINTS, TEAM_ENDPOINTS, or TEAM_PAIR_ENDPOINTS).
3. Add the table name to scripts/push_to_prod.py and pull_from_prod.py.
No new file needed unless the endpoint has unusual logic.
"""

import argparse
import logging

from db import connect, ensure_schema, truncate_all
from ingest_types import load_types
from ingest_league import load_league
from ingest_seasons import load_seasons
from ingest_fixtures import load_fixtures_full, load_fixtures_incremental
from ingest_squads import load_squads
from ingest import (
    load_season_endpoints,
    load_stage_endpoints,
    load_round_endpoints,
    load_team_endpoints,
    load_team_pair_endpoints,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

# ── Endpoint registry ────────────────────────────────────────────────────────

SEASON_ENDPOINTS = [
    {"table": "sportmonks__stages",    "path": "/stages/seasons/{season_id}"},
    {"table": "sportmonks__rounds",    "path": "/rounds/seasons/{season_id}"},
    {"table": "sportmonks__teams",     "path": "/teams/seasons/{season_id}",     "includes": "venue;coaches"},
    {"table": "sportmonks__venues",    "path": "/venues/seasons/{season_id}"},
    {"table": "sportmonks__referees",  "path": "/referees/seasons/{season_id}",  "includes": "country"},
    {"table": "sportmonks__standings", "path": "/standings/seasons/{season_id}", "includes": "participant;details;rule"},
    {"table": "sportmonks__topscorers","path": "/topscorers/seasons/{season_id}","includes": "player;participant;type"},
]

STAGE_ENDPOINTS = [
    {"table": "sportmonks__stage_topscorers", "path": "/topscorers/stages/{stage_id}", "includes": "player;participant;type"},
    {"table": "sportmonks__stage_statistics", "path": "/statistics/stages/{stage_id}", "includes": "type"},
]

ROUND_ENDPOINTS = [
    {"table": "sportmonks__round_statistics", "path": "/statistics/rounds/{round_id}", "includes": "type"},
]

TEAM_ENDPOINTS = [
    {"table": "sportmonks__transfers", "path": "/transfers/teams/{team_id}", "includes": "player;fromTeam;toTeam;type"},
    {"table": "sportmonks__rivals",    "path": "/rivals/teams/{team_id}"},
]

TEAM_PAIR_ENDPOINTS = [
    {"table": "sportmonks__h2h", "path": "/fixtures/head-to-head/{team1_id}/{team2_id}", "includes": "scores;participants;state;events;statistics;referees.referee;periods"},
]

# ── Runner ───────────────────────────────────────────────────────────────────

def run(full_load: bool = False) -> None:
    conn = connect()
    ensure_schema(conn)

    log.info("=== %s ===", "Full load" if full_load else "Incremental load")

    if full_load:
        truncate_all(conn)

    load_types(conn)
    load_league(conn)
    seasons = load_seasons(conn)
    scope = seasons if full_load else [s for s in seasons if s.get("is_current")]

    # Fixtures: date-chunked (full) or fixed-window (incremental)
    if full_load:
        load_fixtures_full(conn, seasons)
    else:
        load_fixtures_incremental(conn)

    # Squads: season × team nested URL — handled separately
    load_squads(conn, scope)

    load_season_endpoints(conn, scope, SEASON_ENDPOINTS)
    load_stage_endpoints(conn, scope, STAGE_ENDPOINTS)
    load_round_endpoints(conn, scope, ROUND_ENDPOINTS)
    load_team_endpoints(conn, scope, TEAM_ENDPOINTS)
    load_team_pair_endpoints(conn, scope, TEAM_PAIR_ENDPOINTS)

    conn.close()
    log.info("Done")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--full-load", action="store_true", help="Full historical load from 2010/2011 onwards")
    args = parser.parse_args()
    run(full_load=args.full_load)
