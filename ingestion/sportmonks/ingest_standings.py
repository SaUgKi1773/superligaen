"""
Fetch standings per season with full details (W/D/L, GF/GA, home/away/overall).
"""

import logging

from api import get
from db import upsert

log = logging.getLogger(__name__)


def load_standings(conn, seasons: list[dict]) -> None:
    for season in seasons:
        season_id = season["id"]
        data = get(f"/standings/seasons/{season_id}", params={"include": "participant;details"})
        rows = data.get("data", [])
        for row in rows:
            upsert(conn, "sportmonks__standings", row["id"], row, f"sportmonks/standings/seasons/{season_id}")
        log.info("Standings season %s: %d rows", season["name"], len(rows))
