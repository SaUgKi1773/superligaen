"""
Sportmonks bronze ingestion entry point.

Usage:
  python run.py                # incremental — last 3 days + 4 weeks ahead
  python run.py --full-load    # full historical load from 2010/2011 onwards

Run from the ingestion/sportmonks/ directory, or set DUCKDB_PATH explicitly.
"""

import argparse
import logging

from db import connect, ensure_schema
from ingest_seasons import load_seasons
from ingest_fixtures import load_fixtures_full, load_fixtures_incremental
from ingest_standings import load_standings

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)


def run(full_load: bool = False) -> None:
    conn = connect()
    ensure_schema(conn)

    seasons = load_seasons(conn)

    if full_load:
        log.info("=== Full load ===")
        load_fixtures_full(conn, seasons)
        load_standings(conn, seasons)
    else:
        log.info("=== Incremental load ===")
        current = [s for s in seasons if s.get("is_current")]
        load_fixtures_incremental(conn)
        load_standings(conn, current)

    conn.close()
    log.info("Done")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--full-load", action="store_true", help="Full historical load from 2010/2011 onwards")
    args = parser.parse_args()
    run(full_load=args.full_load)
