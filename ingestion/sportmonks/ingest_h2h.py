"""
Fetch head-to-head fixtures for all unique team pairs seen across seasons.
Endpoint: /v3/football/fixtures/head-to-head/{team1_id}/{team2_id}
Stored in sportmonks__h2h — same fixture shape but separate table.
"""

import itertools
import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_h2h(conn, seasons: list) -> None:
    team_ids: set[int] = set()
    for season in seasons:
        season_id = season["id"]
        teams = get_paginated(f"/teams/seasons/{season_id}")
        for t in teams:
            team_ids.add(t["id"])

    pairs = list(itertools.combinations(sorted(team_ids), 2))
    log.info("H2H: %d teams → %d pairs", len(team_ids), len(pairs))

    seen: set[int] = set()
    total = 0
    for team1, team2 in pairs:
        fixtures = get_paginated(f"/fixtures/head-to-head/{team1}/{team2}")
        for f in fixtures:
            if f["id"] not in seen:
                seen.add(f["id"])
                upsert(conn, "sportmonks__h2h", f["id"], f, f"sportmonks/fixtures/head-to-head/{team1}/{team2}")
                total += 1

    log.info("H2H fixtures: %d upserted", total)
