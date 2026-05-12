"""Fetch and store Superliga league metadata."""

import logging

from api import get
from config import LEAGUE_ID
from db import upsert

log = logging.getLogger(__name__)


def load_league(conn) -> None:
    data = get(f"/leagues/{LEAGUE_ID}")
    league = data["data"]
    upsert(conn, "sportmonks__league", league["id"], league, "sportmonks/leagues")
    log.info("League: %s (id=%d)", league["name"], league["id"])
