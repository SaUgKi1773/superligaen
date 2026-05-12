"""
Fetch fixtures with all includes embedded.
Chunks date ranges into 90-day windows to stay under the 100-day API limit.
"""

import logging
from datetime import date, timedelta

from api import get_paginated
from config import DATE_CHUNK_DAYS, FIXTURE_INCLUDES, LEAGUE_ID
from db import upsert

log = logging.getLogger(__name__)


def _chunks(start: date, end: date):
    cursor = start
    while cursor <= end:
        yield cursor.isoformat(), min(cursor + timedelta(days=DATE_CHUNK_DAYS - 1), end).isoformat()
        cursor += timedelta(days=DATE_CHUNK_DAYS)


def _ingest_window(conn, from_date: str, to_date: str) -> int:
    records = get_paginated(
        f"/fixtures/between/{from_date}/{to_date}",
        params={"filters": f"leagueIds:{LEAGUE_ID}", "include": FIXTURE_INCLUDES},
    )
    for fixture in records:
        upsert(conn, "sportmonks__fixtures", fixture["id"], fixture, "sportmonks/fixtures")
    log.info("Fixtures %s → %s: %d upserted", from_date, to_date, len(records))
    return len(records)


def load_fixtures_full(conn, seasons: list[dict]) -> None:
    total = 0
    for season in seasons:
        start = date.fromisoformat(season["starting_at"])
        end   = date.fromisoformat(season["ending_at"])
        log.info("Season %s (%s → %s)", season["name"], start, end)
        for from_date, to_date in _chunks(start, end):
            total += _ingest_window(conn, from_date, to_date)
    log.info("Full fixture load complete — %d total", total)


def load_fixtures_incremental(conn) -> None:
    from_date = (date.today() - timedelta(days=3)).isoformat()
    to_date   = (date.today() + timedelta(weeks=4)).isoformat()
    _ingest_window(conn, from_date, to_date)
