"""
Group 1: League endpoint.
Filter: league_id

Always runs first in every load mode. Stores league metadata including
the seasons list, which is used by db.get_current_season() to determine
which season is currently active.
"""

import logging

from api import api_get
from config import LEAGUE_ENDPOINT
from db import _delete_insert

log = logging.getLogger(__name__)


def load_leagues(conn, league_id: int) -> None:
    table, endpoint = LEAGUE_ENDPOINT
    log.info("League %d: loading league data", league_id)
    try:
        data = api_get(endpoint, {"id": league_id})["response"]
        _delete_insert(conn, table, ["league_id"], [league_id], data)
    except Exception as exc:
        log.warning("Failed %s league %d: %s", table, league_id, exc)
