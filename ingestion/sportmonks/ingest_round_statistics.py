"""
Fetch aggregate statistics per round.
Endpoint: /v3/football/statistics/rounds/{round_id}
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_round_statistics(conn, seasons: list) -> None:
    seen: set[int] = set()
    total = 0

    for season in seasons:
        season_id = season["id"]
        rounds = get_paginated(f"/rounds/seasons/{season_id}")
        for rnd in rounds:
            round_id = rnd["id"]
            records = get_paginated(f"/statistics/rounds/{round_id}")
            for r in records:
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, "sportmonks__round_statistics", r["id"], r, f"sportmonks/statistics/rounds/{round_id}")
                    total += 1

    log.info("Round statistics: %d upserted", total)
