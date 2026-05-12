"""
Group 2: Season endpoints.
Filter: league_id + season

Covers all endpoints that return one dataset per league+season:
standings, topscorers, topassists, topyellowcards, topredcards,
injuries, teams, rounds, and players (paginated).

Load strategies:
  Initial load  — plain INSERT (tables already wiped by truncate_all)
  Seasonal load — DELETE by (season, league_id) + INSERT
  Daily load    — DELETE by (current_season, league_id) + INSERT
"""

import logging

from api import api_get
from config import SEASON_ENDPOINTS, SEASON_PLAYERS_ENDPOINT
from db import SEASON_PLAYERS_TABLE, _delete_insert, _insert

log = logging.getLogger(__name__)


def load_season(conn, league_id: int, season: int, incremental: bool = False) -> None:
    log.info("League %d season %d: loading season data", league_id, season)
    write = _delete_insert if incremental else _insert

    for table, endpoint in SEASON_ENDPOINTS:
        try:
            data = api_get(endpoint, {"league": league_id, "season": season})["response"]
            write(conn, table, ["season", "league_id"], [season, league_id], data)
        except Exception as exc:
            log.warning("Failed %s league %d season %d: %s", table, league_id, season, exc)

    # Players — paginated; always delete-before-insert regardless of mode
    table, endpoint = SEASON_PLAYERS_ENDPOINT
    try:
        conn.execute(
            f"DELETE FROM bronze.{SEASON_PLAYERS_TABLE} WHERE season = ? AND league_id = ?",
            [season, league_id],
        )
        page = 1
        while True:
            data = api_get(endpoint, {"league": league_id, "season": season, "page": page})
            _insert(conn, table, ["season", "league_id", "page"], [season, league_id, page],
                    data["response"])
            if page >= data["paging"]["total"]:
                break
            page += 1
    except Exception as exc:
        log.warning("Failed %s league %d season %d: %s", table, league_id, season, exc)
