"""
Fetch aggregate statistics per stage.
Endpoint: /v3/football/statistics/stages/{stage_id}
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_stage_statistics(conn, seasons: list) -> None:
    seen: set[int] = set()
    total = 0

    for season in seasons:
        season_id = season["id"]
        stages = get_paginated(f"/stages/seasons/{season_id}")
        for stage in stages:
            stage_id = stage["id"]
            records = get_paginated(f"/statistics/stages/{stage_id}")
            for r in records:
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, "sportmonks__stage_statistics", r["id"], r, f"sportmonks/statistics/stages/{stage_id}")
                    total += 1

    log.info("Stage statistics: %d upserted", total)
