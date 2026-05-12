"""
Fetch all Superliga seasons and return the in-scope list for downstream use.
Always runs first — other modules depend on the season list.
"""

import logging

from api import get
from config import FIRST_SEASON_YEAR, LEAGUE_ID
from db import upsert

log = logging.getLogger(__name__)


def load_seasons(conn) -> list[dict]:
    data = get(f"/leagues/{LEAGUE_ID}", params={"include": "seasons"})
    all_seasons = data["data"].get("seasons", [])

    in_scope = [
        s for s in all_seasons
        if int(s["name"][:4]) >= FIRST_SEASON_YEAR
    ]

    for season in in_scope:
        upsert(conn, "sportmonks__seasons", season["id"], season, "sportmonks/seasons")

    log.info(
        "Seasons: %d in scope (%d/XX onwards), %d total available",
        len(in_scope), FIRST_SEASON_YEAR, len(all_seasons),
    )
    return in_scope
