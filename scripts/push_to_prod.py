"""
Push local DuckDB → MotherDuck.

Discovers all schemas and tables dynamically from the local file.
Nukes the target schemas before uploading.

Usage:
  python scripts/push_to_prod.py                        # → superligaen (prod), all schemas
  python scripts/push_to_prod.py --db superligaen_dev   # → different target db
  python scripts/push_to_prod.py --schema gold           # → only the gold schema
  python scripts/push_to_prod.py --schema gold silver    # → gold and silver only
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
    parser.add_argument("--schema", nargs="+", metavar="SCHEMA", help="Only push these schemas (default: all)")
    args = parser.parse_args()

    local_path = os.environ.get("DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb"))
    token = os.environ["MOTHERDUCK_TOKEN"]

    # Discover tables from local file
    log.info("Reading table list from local: %s", local_path)
    local = duckdb.connect(local_path, read_only=True)
    all_tables = local.execute("""
        SELECT schema_name, table_name
        FROM duckdb_tables()
        WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'main')
        ORDER BY schema_name, table_name
    """).fetchall()
    local.close()

    if args.schema:
        requested = set(args.schema)
        tables = [(s, t) for s, t in all_tables if s in requested]
        unknown = requested - {s for s, _ in all_tables}
        if unknown:
            log.warning("Schemas not found in local file: %s", sorted(unknown))
    else:
        tables = all_tables

    schemas = sorted({schema for schema, _ in tables})
    log.info("Found %d tables across schemas: %s", len(tables), schemas)

    # Connect to MotherDuck and push
    log.info("Connecting to MotherDuck: %s", args.db)
    conn = duckdb.connect(f"md:{args.db}?motherduck_token={token}")
    conn.execute(f"ATTACH '{local_path}' AS local (READ_ONLY)")

    # Nuke and recreate each schema
    for schema in schemas:
        log.info("Nuking schema: %s", schema)
        conn.execute(f"DROP SCHEMA IF EXISTS {schema} CASCADE")
        conn.execute(f"CREATE SCHEMA {schema}")

    # Copy all tables
    total = 0
    for schema, table in tables:
        conn.execute(f"CREATE TABLE {schema}.{table} AS SELECT * FROM local.{schema}.{table}")
        count = conn.execute(f"SELECT COUNT(*) FROM {schema}.{table}").fetchone()[0]
        log.info("  %s.%s → %d rows", schema, table, count)
        total += 1

    conn.close()
    log.info("Done — pushed %d tables to %s", total, args.db)


if __name__ == "__main__":
    main()
