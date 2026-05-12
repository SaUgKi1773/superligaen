"""
Fetch stages per season.
Superliga has multiple stages per season (Regular Season, Championship Round,
Relegation Round) — essential for grouping standings and fixtures correctly.
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_stages(conn, seasons: list[dict]) -> None:
    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/stages/seasons/{season_id}")
        for stage in records:
            upsert(conn, "sportmonks__stages", stage["id"], stage, "sportmonks/stages")
        log.info("Stages season %s: %d upserted", season["name"], len(records))
