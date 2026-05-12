"""
Fetch rival team pairings per team.
Endpoint: /v3/football/rivals/teams/{team_id}
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_rivals(conn, seasons: list) -> None:
    team_ids: set[int] = set()
    for season in seasons:
        season_id = season["id"]
        teams = get_paginated(f"/teams/seasons/{season_id}")
        for t in teams:
            team_ids.add(t["id"])

    seen: set[int] = set()
    total = 0
    for team_id in sorted(team_ids):
        records = get_paginated(f"/rivals/teams/{team_id}")
        for r in records:
            if r["id"] not in seen:
                seen.add(r["id"])
                upsert(conn, "sportmonks__rivals", r["id"], r, f"sportmonks/rivals/teams/{team_id}")
                total += 1

    log.info("Rivals: %d upserted", total)
