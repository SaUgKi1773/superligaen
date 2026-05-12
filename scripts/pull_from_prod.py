"""
Pull MotherDuck prod (superligaen) bronze tables → local DuckDB.
Use this to seed your local database with current production data.

Usage:
  python scripts/pull_from_prod.py
"""

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
    "sportmonks__stage_statistics",
    "sportmonks__round_statistics",
    "sportmonks__transfers",
    "sportmonks__rivals",
]


def main() -> None:
    local_path = os.environ.get("DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb"))
    token = os.environ["MOTHERDUCK_TOKEN"]

    log.info("Connecting to local DuckDB: %s", local_path)
    conn = duckdb.connect(local_path)

    log.info("Attaching MotherDuck prod database (read-only)")
    conn.execute(f"ATTACH 'md:superligaen?motherduck_token={token}' AS prod (READ_ONLY)")
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")

    for table in TABLES:
        conn.execute(f"CREATE OR REPLACE TABLE bronze.{table} AS SELECT * FROM prod.bronze.{table}")
        count = conn.execute(f"SELECT COUNT(*) FROM bronze.{table}").fetchone()[0]
        log.info("Pulled prod.bronze.%s → local: %d rows", table, count)

    conn.close()
    log.info("Pull complete")


if __name__ == "__main__":
    main()
