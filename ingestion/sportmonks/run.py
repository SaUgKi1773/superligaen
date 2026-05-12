"""
Sportmonks bronze ingestion — entry point.

Usage:
  python run.py --load-type full --target local
  python run.py --load-type incremental --target local
  python run.py --load-type incremental --from-date 2026-05-08 --to-date 2026-05-11 --target local
  python run.py --load-type full --target prod            # requires explicit confirmation

Load behaviour:
  full        — truncates bronze, then ingests all seasons from FIRST_SEASON_ID to current.
                Static tables (teams, venues, referees, rounds) refreshed for current season.
                Never run --target prod automatically; always requires --target local first.

  incremental — refreshes standings + topscorers for current season.
                Ingests fixtures (with detail) for last 3 days → 4 weeks ahead (or provided range).
                Static tables are NOT refreshed (run a full load to update them).
"""

import argparse
import logging
import sys
from datetime import date, timedelta

from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)


def run(
    load_type: str,
    target: str,
    from_date: str | None = None,
    to_date: str | None = None,
) -> None:
    # Imported here so SPORTMONKS_KEY / MOTHERDUCK_TOKEN are loaded first
    from db import connect, ensure_schema, get_current_season_id, truncate_all

    conn = connect(target)
    ensure_schema(conn)

    if load_type == "full":
        _run_full(conn, target)
    else:
        _run_incremental(conn, from_date, to_date)

    conn.close()
    log.info("Bronze ingestion complete (%s / %s)", load_type, target)


def _run_full(conn, target: str) -> None:
    from config import FIRST_SEASON_ID, LEAGUE_ID
    from db import delete_fixtures_for_season, truncate_all
    from ingest_static import load_leagues, load_seasons, load_teams, load_venues, load_referees, load_rounds
    from ingest_standings import load_standings, load_topscorers
    from ingest_fixtures import load_fixtures_for_season, load_fixture_details

    log.info("Full load — target: %s", target)
    truncate_all(conn)

    # Step 1: leagues + seasons (determines season list)
    load_leagues(conn)
    load_seasons(conn, LEAGUE_ID)

    # Step 2: find season IDs from FIRST_SEASON_ID onwards
    rows = conn.execute(
        "SELECT season_id, raw_json->>'$.name' FROM bronze.sportmonks__seasons "
        "WHERE season_id >= ? ORDER BY season_id",
        [FIRST_SEASON_ID],
    ).fetchall()
    season_ids = [r[0] for r in rows]
    log.info("Found %d seasons to process (from season_id %d onwards)", len(season_ids), FIRST_SEASON_ID)

    # Step 3: static reference data + season-level data + fixtures for all seasons
    for season_id in season_ids:
        log.info("=== Season %d ===", season_id)
        load_teams(conn, season_id)
        load_venues(conn, season_id)
        load_referees(conn, season_id)
        load_rounds(conn, season_id)
        load_standings(conn, season_id)
        load_topscorers(conn, season_id)
        fixture_ids = load_fixtures_for_season(conn, season_id)
        load_fixture_details(conn, fixture_ids)


def _run_incremental(conn, from_date: str | None, to_date: str | None) -> None:
    from config import LEAGUE_ID
    from db import get_current_season_id
    from ingest_static import load_leagues, load_seasons, load_teams, load_venues, load_referees, load_rounds
    from ingest_standings import load_standings, load_topscorers
    from ingest_fixtures import load_fixtures_for_date_range, load_fixture_details

    current_season_id = get_current_season_id(conn)
    log.info("Incremental load — current season: %d", current_season_id)

    # Refresh all static tables for current season
    load_leagues(conn)
    load_seasons(conn, LEAGUE_ID)
    load_teams(conn, current_season_id)
    load_venues(conn, current_season_id)
    load_referees(conn, current_season_id)
    load_rounds(conn, current_season_id)

    # Refresh standings + topscorers
    load_standings(conn, current_season_id)
    load_topscorers(conn, current_season_id)

    # Fixtures: default window = last 3 days to 4 weeks ahead
    if not from_date:
        from_date = (date.today() - timedelta(days=3)).isoformat()
    if not to_date:
        to_date = (date.today() + timedelta(weeks=4)).isoformat()

    log.info("Fixture window: %s → %s", from_date, to_date)
    fixture_ids = load_fixtures_for_date_range(conn, from_date, to_date)
    load_fixture_details(conn, fixture_ids)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sportmonks bronze ingestion")
    parser.add_argument(
        "--load-type", choices=["full", "incremental"], required=True,
        help="'full' rebuilds all history; 'incremental' refreshes current window",
    )
    parser.add_argument(
        "--target", choices=["local", "prod"], default="local",
        help="'local' writes to local_dev.duckdb; 'prod' writes to MotherDuck (default: local)",
    )
    parser.add_argument("--from-date", default=None, help="Start date for fixture window (YYYY-MM-DD)")
    parser.add_argument("--to-date",   default=None, help="End date for fixture window (YYYY-MM-DD)")
    args = parser.parse_args()

    if args.target == "prod" and args.load_type == "full":
        print("ERROR: --load-type full --target prod is not allowed. Run full loads locally only.")
        sys.exit(1)

    run(
        load_type=args.load_type,
        target=args.target,
        from_date=args.from_date,
        to_date=args.to_date,
    )
