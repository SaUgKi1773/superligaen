"""
Sportmonks bronze ingestion entry point.

Usage:
  python run.py                # incremental — last 3 days + 4 weeks ahead
  python run.py --full-load    # full historical load from 2010/2011 onwards

Run from the ingestion/sportmonks/ directory, or set DUCKDB_PATH explicitly.

Adding a new endpoint
---------------------
1. Create ingest_<name>.py with a load_<name>(conn, seasons) function.
2. Add the table to db.py BRONZE_TABLES.
3. Import load_<name> here and append it to SEASON_LOADERS.
4. Add the table name to scripts/push_to_prod.py and pull_from_prod.py.
"""

import argparse
import logging

from db import connect, ensure_schema
from ingest_types import load_types
from ingest_league import load_league
from ingest_seasons import load_seasons
from ingest_stages import load_stages
from ingest_rounds import load_rounds
from ingest_teams import load_teams
from ingest_venues import load_venues
from ingest_referees import load_referees
from ingest_squads import load_squads
from ingest_fixtures import load_fixtures_full, load_fixtures_incremental
from ingest_standings import load_standings
from ingest_topscorers import load_topscorers
from ingest_stage_statistics import load_stage_statistics
from ingest_round_statistics import load_round_statistics
from ingest_transfers import load_transfers
from ingest_rivals import load_rivals
from ingest_h2h import load_h2h

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

# Called once with no season scope.
GLOBAL_LOADERS = [
    load_types,
    load_league,
]

# Called with (conn, seasons). Add/remove endpoints here.
SEASON_LOADERS = [
    load_stages,
    load_rounds,
    load_teams,
    load_venues,
    load_referees,
    load_squads,
    load_standings,
    load_topscorers,
    load_stage_statistics,
    load_round_statistics,
    load_transfers,
    load_rivals,
    load_h2h,
]


def run(full_load: bool = False) -> None:
    conn = connect()
    ensure_schema(conn)

    for loader in GLOBAL_LOADERS:
        loader(conn)

    seasons = load_seasons(conn)
    scope = seasons if full_load else [s for s in seasons if s.get("is_current")]

    log.info("=== %s ===", "Full load" if full_load else "Incremental load")

    # Fixtures are date-chunked (full) or fixed-window (incremental) — handled separately.
    if full_load:
        load_fixtures_full(conn, seasons)
    else:
        load_fixtures_incremental(conn)

    for loader in SEASON_LOADERS:
        loader(conn, scope)

    conn.close()
    log.info("Done")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--full-load", action="store_true", help="Full historical load from 2010/2011 onwards")
    args = parser.parse_args()
    run(full_load=args.full_load)
