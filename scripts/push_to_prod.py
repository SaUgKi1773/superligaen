"""
Push local DuckDB bronze tables → MotherDuck prod (superligaen).
Runs after ingestion to promote validated local data to production.

Usage:
  python scripts/push_to_prod.py
"""

import logging
import os
import sys

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TABLES = [
    "sportmonks__seasons",
    "sportmonks__fixtures",
    "sportmonks__standings",
]


def main() -> None:
    local_path = os.environ.get("DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb"))
    token = os.environ["MOTHERDUCK_TOKEN"]

    log.info("Connecting to local DuckDB: %s", local_path)
    conn = duckdb.connect(local_path)

    log.info("Attaching MotherDuck prod database")
    conn.execute(f"ATTACH 'md:superligaen?motherduck_token={token}' AS prod")
    conn.execute("CREATE SCHEMA IF NOT EXISTS prod.bronze")

    for table in TABLES:
        conn.execute(f"CREATE OR REPLACE TABLE prod.bronze.{table} AS SELECT * FROM bronze.{table}")
        count = conn.execute(f"SELECT COUNT(*) FROM prod.bronze.{table}").fetchone()[0]
        log.info("Pushed bronze.%s → prod: %d rows", table, count)

    conn.close()
    log.info("Push complete")


if __name__ == "__main__":
    main()
