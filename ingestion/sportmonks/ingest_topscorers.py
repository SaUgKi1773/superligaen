"""
Fetch topscorers at season level and stage level.
Endpoints:
  /v3/football/topscorers/seasons/{season_id}
  /v3/football/topscorers/stages/{stage_id}
Both share the same table; records have unique ids.
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_topscorers(conn, seasons: list) -> None:
    seen: set[int] = set()
    total = 0

    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/topscorers/seasons/{season_id}")
        for r in records:
            if r["id"] not in seen:
                seen.add(r["id"])
                upsert(conn, "sportmonks__topscorers", r["id"], r, f"sportmonks/topscorers/seasons/{season_id}")
                total += 1

        stages = get_paginated(f"/stages/seasons/{season_id}")
        for stage in stages:
            stage_id = stage["id"]
            records = get_paginated(f"/topscorers/stages/{stage_id}")
            for r in records:
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, "sportmonks__topscorers", r["id"], r, f"sportmonks/topscorers/stages/{stage_id}")
                    total += 1

    log.info("Topscorers: %d upserted", total)
