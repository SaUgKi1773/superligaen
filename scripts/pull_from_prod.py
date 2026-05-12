"""
Pull MotherDuck bronze tables → local DuckDB.
Use this to seed your local database from any MotherDuck database.

Usage:
  python scripts/pull_from_prod.py                        # ← superligaen (prod)
  python scripts/pull_from_prod.py --db superligaen_dev   # ← superligaen_dev
"""

import argparse
import logging
import os

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TABLES = [
    "sportmonks__types",
    "sportmonks__league",
    "sportmonks__seasons",
    "sportmonks__stages",
    "sportmonks__rounds",
    "sportmonks__teams",
    "sportmonks__venues",
    "sportmonks__referees",
    "sportmonks__squads",
    "sportmonks__fixtures",
    "sportmonks__h2h",
    "sportmonks__standings",
    "sportmonks__topscorers",
    "sportmonks__stage_topscorers",
    "sportmonks__stage_statistics",
    "sportmonks__round_statistics",
    "sportmonks__transfers",
    "sportmonks__rivals",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="superligaen", help="MotherDuck database name (default: superligaen)")
    args = parser.parse_args()

    local_path = os.environ.get("DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb"))
    token = os.environ["MOTHERDUCK_TOKEN"]

    log.info("Connecting to MotherDuck: %s", args.db)
    conn = duckdb.connect(f"md:{args.db}?motherduck_token={token}")

    log.info("Attaching local DuckDB: %s", local_path)
    conn.execute(f"ATTACH '{local_path}' AS local")
    conn.execute("CREATE SCHEMA IF NOT EXISTS local.bronze")

    for table in TABLES:
        conn.execute(f"CREATE OR REPLACE TABLE local.bronze.{table} AS SELECT * FROM bronze.{table}")
        count = conn.execute(f"SELECT COUNT(*) FROM local.bronze.{table}").fetchone()[0]
        log.info("Pulled %s.bronze.%s → local: %d rows", args.db, table, count)

    conn.close()
    log.info("Pull complete ← %s", args.db)


if __name__ == "__main__":
    main()
