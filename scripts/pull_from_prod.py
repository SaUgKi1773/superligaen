"""
Pull MotherDuck → local DuckDB.

Discovers all schemas and tables dynamically from the MotherDuck source.
Nukes the local schemas before downloading.

Usage:
  python scripts/pull_from_prod.py                # ← superligaen (prod)
  python scripts/pull_from_prod.py --db test
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

SKIP_SCHEMAS = {"information_schema", "pg_catalog", "main"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="superligaen", help="MotherDuck database name (default: superligaen)")
    args = parser.parse_args()

    local_path = os.environ.get("DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb"))
    token = os.environ["MOTHERDUCK_TOKEN"]

    log.info("Connecting to MotherDuck: %s", args.db)
    conn = duckdb.connect(f"md:{args.db}?motherduck_token={token}")

    # Discover tables from MotherDuck source
    tables = conn.execute(f"""
        SELECT schema_name, table_name
        FROM duckdb_tables()
        WHERE database_name = '{args.db}'
          AND schema_name NOT IN ('information_schema', 'pg_catalog', 'main')
        ORDER BY schema_name, table_name
    """).fetchall()

    schemas = sorted({schema for schema, _ in tables})
    log.info("Found %d tables across schemas: %s", len(tables), schemas)

    log.info("Attaching local DuckDB: %s", local_path)
    conn.execute(f"ATTACH '{local_path}' AS local")

    # Nuke and recreate each local schema
    for schema in schemas:
        log.info("Nuking local schema: %s", schema)
        conn.execute(f"DROP SCHEMA IF EXISTS local.{schema} CASCADE")
        conn.execute(f"CREATE SCHEMA local.{schema}")

    # Copy all tables
    total = 0
    for schema, table in tables:
        conn.execute(f"CREATE TABLE local.{schema}.{table} AS SELECT * FROM {schema}.{table}")
        count = conn.execute(f"SELECT COUNT(*) FROM local.{schema}.{table}").fetchone()[0]
        log.info("  %s.%s → %d rows", schema, table, count)
        total += 1

    conn.close()
    log.info("Done — pulled %d tables from %s", total, args.db)


if __name__ == "__main__":
    main()
