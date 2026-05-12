"""
Fetch squad (player roster) data per season per team.
Endpoint: /v3/football/squads/seasons/{season_id}/teams/{team_id}
"""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_squads(conn, seasons: list) -> None:
    seen: set[int] = set()
    total = 0

    for season in seasons:
        season_id = season["id"]
        teams = get_paginated(f"/teams/seasons/{season_id}")
        for team in teams:
            team_id = team["id"]
            players = get_paginated(f"/squads/seasons/{season_id}/teams/{team_id}")
            for p in players:
                if p["id"] not in seen:
                    seen.add(p["id"])
                    upsert(conn, "sportmonks__squads", p["id"], p, f"sportmonks/squads/seasons/{season_id}/teams/{team_id}")
                    total += 1

    log.info("Squads: %d upserted", total)
