"""
Sportmonks bronze ingestion entry point.

Usage
-----
  python run.py --mode full --db /path/to/local.duckdb
  python run.py --mode incremental --db md:superligaen
  python run.py --mode incremental          # uses DUCKDB_PATH env var or config default

Modes
-----
  full          Full historical load from 2010/2011 onwards.
                Every table is deleted and reloaded from scratch.

  incremental   Daily refresh (default).
                Global tables  → truncate + reload (seasons may change)
                Seasonal tables→ delete current season + reload
                Fixtures       → delete last 30 days + reload

Delete strategy by table type
------------------------------
  Global    (types, league, seasons, coaches, transfers, rivals, h2h)
            → DELETE FROM table (full truncate), then reload

  Seasonal  (stages, rounds, teams, venues, referees, squads, standings,
             topscorers, stage_topscorers, stage_statistics, round_statistics)
            → DELETE WHERE _season_id = ?, then reload

  Date-win  (fixtures)
            → DELETE WHERE _fixture_date BETWEEN ?, ?, then reload
"""

import argparse
import logging
import os
import sys

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

from db import connect, ensure_schema
from loaders import (
    load_types, load_league, load_seasons,
    load_stages, load_rounds, load_teams,
    load_squads, load_venues, load_referees,
    load_standings, load_topscorers,
    load_stage_topscorers, load_stage_statistics, load_round_statistics,
    load_coaches, load_transfers, load_rivals, load_h2h,
    load_fixtures_full, load_fixtures_incremental,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


def run_full(conn) -> None:
    log.info("=== FULL LOAD START ===")

    # 1. Global lookup tables
    load_types(conn)
    load_league(conn)
    seasons = load_seasons(conn)

    # 2. Seasonal tables — all seasons
    stage_map = load_stages(conn, seasons)
    round_map = load_rounds(conn, seasons)
    team_map  = load_teams(conn, seasons)

    load_squads(conn, seasons, team_map)
    load_venues(conn, seasons)
    load_referees(conn, seasons)
    load_standings(conn, seasons)
    load_topscorers(conn, seasons)
    load_stage_topscorers(conn, seasons, stage_map)
    load_stage_statistics(conn, seasons, stage_map)
    load_round_statistics(conn, seasons, round_map)

    # 3. Global team-based tables (all teams across all seasons)
    load_coaches(conn, team_map)
    load_transfers(conn, team_map)
    load_rivals(conn, team_map)
    load_h2h(conn, team_map)

    # 4. Fixtures — all historical date windows
    load_fixtures_full(conn, seasons)

    log.info("=== FULL LOAD COMPLETE ===")


def run_incremental(conn) -> None:
    log.info("=== INCREMENTAL LOAD START ===")

    # Seasons always truncate+reload — a new season may have started
    seasons = load_seasons(conn)

    # Determine current season(s)
    current = [s for s in seasons if s.get("is_current")]
    if not current:
        current = [max(seasons, key=lambda s: s["starting_at"])]
    log.info("Current season(s): %s", [s["name"] for s in current])

    # Seasonal tables — current season only
    stage_map = load_stages(conn, current)
    round_map = load_rounds(conn, current)
    team_map  = load_teams(conn, current)

    load_squads(conn, current, team_map)
    load_venues(conn, current)
    load_referees(conn, current)
    load_standings(conn, current)
    load_topscorers(conn, current)
    load_stage_topscorers(conn, current, stage_map)
    load_stage_statistics(conn, current, stage_map)
    load_round_statistics(conn, current, round_map)

    # Fixtures — last 30 days
    load_fixtures_incremental(conn)

    log.info("=== INCREMENTAL LOAD COMPLETE ===")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sportmonks football bronze ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="full = initial historical load; incremental = daily refresh (default)",
    )
    parser.add_argument(
        "--db",
        default=None,
        metavar="PATH_OR_URL",
        help="DuckDB file path or MotherDuck URL (e.g. md:superligaen). "
             "Falls back to DUCKDB_PATH env var, then config default.",
    )
    args = parser.parse_args()

    if "SPORTMONKS_API_KEY" not in os.environ:
        log.error("SPORTMONKS_API_KEY is not set — check your .env file")
        sys.exit(1)

    conn = connect(args.db)
    ensure_schema(conn)

    if args.mode == "full":
        run_full(conn)
    else:
        run_incremental(conn)

    conn.close()


if __name__ == "__main__":
    main()
