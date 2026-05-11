"""
Static / reference data ingestion.

Endpoints:
  load_leagues   — /leagues (all accessible leagues)
  load_seasons   — /leagues/{id}?include=seasons (all seasons for a league)
  load_teams     — /teams/seasons/{season_id}
  load_venues    — /venues/seasons/{season_id}
  load_referees  — /referees/seasons/{season_id}
  load_rounds    — /rounds/seasons/{season_id}

All functions do a full upsert — safe to re-run.
"""

import logging

import duckdb

from api import api_get, api_get_all
from config import LEAGUE_ID, TBL_LEAGUES, TBL_REFEREES, TBL_ROUNDS, TBL_SEASONS, TBL_TEAMS, TBL_VENUES
from db import upsert

log = logging.getLogger(__name__)


def load_leagues(conn: duckdb.DuckDBPyConnection) -> None:
    log.info("Loading leagues")
    data = api_get("leagues")
    for league in data.get("data", []):
        upsert(conn, TBL_LEAGUES, ["league_id"], [league["id"]], league)
    log.info("Leagues: %d rows", len(data.get("data", [])))


def load_seasons(conn: duckdb.DuckDBPyConnection, league_id: int) -> None:
    log.info("Loading seasons for league %d", league_id)
    data = api_get(f"leagues/{league_id}", params={"include": "seasons"})
    seasons = data.get("data", {}).get("seasons", [])
    for season in seasons:
        upsert(conn, TBL_SEASONS, ["season_id"], [season["id"]], season)
    log.info("Seasons: %d rows", len(seasons))


def load_teams(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading teams for season %d", season_id)
    count = 0
    for page in api_get_all(f"teams/seasons/{season_id}"):
        for team in page.get("data", []):
            upsert(conn, TBL_TEAMS, ["season_id", "team_id"], [season_id, team["id"]], team)
            count += 1
    log.info("Teams: %d rows", count)


def load_venues(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading venues for season %d", season_id)
    count = 0
    for page in api_get_all(f"venues/seasons/{season_id}"):
        for venue in page.get("data", []):
            upsert(conn, TBL_VENUES, ["venue_id"], [venue["id"]], venue)
            count += 1
    log.info("Venues: %d rows", count)


def load_referees(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading referees for season %d", season_id)
    count = 0
    for page in api_get_all(f"referees/seasons/{season_id}"):
        for referee in page.get("data", []):
            upsert(conn, TBL_REFEREES, ["referee_id"], [referee["id"]], referee)
            count += 1
    log.info("Referees: %d rows", count)


def load_rounds(conn: duckdb.DuckDBPyConnection, season_id: int) -> None:
    log.info("Loading rounds for season %d", season_id)
    count = 0
    for page in api_get_all(f"rounds/seasons/{season_id}"):
        for rnd in page.get("data", []):
            upsert(conn, TBL_ROUNDS, ["round_id"], [rnd["id"]], rnd)
            count += 1
    log.info("Rounds: %d rows", count)
