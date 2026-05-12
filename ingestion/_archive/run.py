"""
Master orchestrator — entry point for all ingestion runs.

Load modes:
  Daily incremental  — refreshes current season data; fixtures loaded
                       by date window only
  Seasonal load      — reloads all data for one specific season
  Initial / full load — loads all seasons from FIRST_SEASON to current

Usage:
  python ingestion/run.py                                  # daily incremental
  python ingestion/run.py --lookback 5                     # custom lookback window
  python ingestion/run.py --full-load                      # all leagues, all seasons
  python ingestion/run.py --full-load --league 119         # one league, all seasons
  python ingestion/run.py --full-load --season 2025        # all leagues, one season
  python ingestion/run.py --full-load --league 119 --season 2025
  python ingestion/run.py --db superligaen                 # target prod database
"""

import argparse
import logging
from datetime import date, timedelta

from config import FIRST_SEASON, LEAGUES
from db import connect, delete_season, ensure_schema_and_tables, get_current_season, get_league_country, truncate_all
from ingest_country import load_country
from ingest_fixtures import delete_fixture_window, load_fixtures
from ingest_leagues import load_leagues
from ingest_season import load_season

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)


def run(
    lookback_days: int = 2,
    full_load: bool = False,
    league_id: int | None = None,
    season: int | None = None,
    target_db: str | None = None,
) -> None:
    conn = connect(target_db)
    ensure_schema_and_tables(conn)

    leagues = [l for l in LEAGUES if league_id is None or l["id"] == league_id]
    if not leagues:
        raise ValueError(f"League {league_id} not found in config.LEAGUES")

    if full_load:
        # Wipe everything only when loading all leagues and all seasons
        if not league_id and not season:
            truncate_all(conn)

        for league in leagues:
            lid = league["id"]

            # Group 1 — leagues (also determines current season and country)
            load_leagues(conn, lid)
            current_season = get_current_season(conn, lid)
            country = get_league_country(conn, lid)
            seasons = [season] if season else list(range(FIRST_SEASON, current_season + 1))
            log.info("Full load — league: %d  country: %s  current season: %d  seasons: %s",
                     lid, country, current_season, seasons)

            for s in seasons:
                log.info("=== League %d  Season %d ===", lid, s)
                if league_id or season:
                    delete_season(conn, lid, s)

                # Group 2 — season data
                load_season(conn, lid, s)

                # Group 3 — fixtures + fixture details
                load_fixtures(conn, lid, s)

            # Group 4 — country data (not season-scoped)
            load_country(conn, lid, country)

    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        log.info("Incremental load — from: %s (to 4 weeks ahead)", from_date)

        for league in leagues:
            lid = league["id"]

            # Group 1 — leagues (also determines current season and country)
            load_leagues(conn, lid)
            current_season = get_current_season(conn, lid)
            country = get_league_country(conn, lid)
            log.info("=== League %d  country: %s  current season: %d ===",
                     lid, country, current_season)

            # Group 2 — season data (full refresh of current season)
            load_season(conn, lid, current_season, incremental=True)

            # Group 3 — fixtures from lookback date to 4 weeks ahead
            to_date = (date.today() + timedelta(weeks=4)).isoformat()
            delete_fixture_window(conn, lid, from_date)
            load_fixtures(conn, lid, current_season, from_date=from_date, to_date=to_date)

            # Group 4 — country data
            load_country(conn, lid, country)

    conn.close()
    log.info("Bronze ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest bronze data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=3,
                        help="Days to look back for finished fixtures (default: 3)")
    parser.add_argument("--full-load", action="store_true",
                        help="Historical load — requires upgraded API plan")
    parser.add_argument("--league", type=int, default=None,
                        help="League ID to load (default: all leagues in config.LEAGUES)")
    parser.add_argument("--season", type=int, default=None,
                        help="Season year for --full-load (e.g. 2025). Omit to load all seasons.")
    parser.add_argument("--db", dest="target_db", default=None,
                        help="Target MotherDuck database (default: $TARGET_DB or 'superligaen_dev')")
    args = parser.parse_args()
    run(
        lookback_days=args.lookback,
        full_load=args.full_load,
        league_id=args.league,
        season=args.season,
        target_db=args.target_db,
    )
