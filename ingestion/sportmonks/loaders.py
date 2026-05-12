"""
All data loading functions for the Sportmonks bronze layer.

Delete strategy per table type
-------------------------------
Global    delete_global    → insert   (types, league, seasons, coaches,
                                        transfers, rivals, h2h)
Seasonal  delete_by_season → insert   (stages, rounds, teams, venues,
                                        referees, squads, standings,
                                        topscorers, stage_*, round_*)
Date-win  delete_by_date   → insert   (fixtures)
"""

import itertools
import json
import logging
from datetime import date, timedelta

import requests

from api import get, get_paginated, CORE_API_BASE
from config import (
    DATE_CHUNK_DAYS, FIRST_SEASON_YEAR, FIXTURE_INCLUDES,
    H2H_INCLUDES, INCREMENTAL_DAYS, LEAGUE_ID,
)
from db import delete_global, delete_by_season, delete_by_date, insert_batch

log = logging.getLogger(__name__)


# ── Internal helpers ──────────────────────────────────────────────────────────

def _date_chunks(start: date, end: date, days: int = DATE_CHUNK_DAYS):
    cursor = start
    while cursor <= end:
        yield cursor.isoformat(), min(cursor + timedelta(days=days - 1), end).isoformat()
        cursor += timedelta(days=days)


def _rows(records, season_id=None, date_fn=None):
    return [
        (r["id"], json.dumps(r), season_id, date_fn(r) if date_fn else None)
        for r in records
    ]


def _all_team_ids(team_map: dict) -> set:
    return {t["id"] for teams in team_map.values() for t in teams}


# ── Core API loaders (reference data, always truncate + reload) ───────────────

def _load_core(conn, path: str, table: str) -> int:
    delete_global(conn, table)
    records = get_paginated(path, base=CORE_API_BASE)
    insert_batch(conn, table, _rows(records))
    log.info("%s: %d rows", table, len(records))
    return len(records)


def load_core_continents(conn) -> int:
    return _load_core(conn, "/continents", "sportmonks__core_continents")


def load_core_countries(conn) -> int:
    return _load_core(conn, "/countries", "sportmonks__core_countries")


def load_core_regions(conn) -> int:
    return _load_core(conn, "/regions", "sportmonks__core_regions")


def load_core_players(conn) -> int:
    """All players accessible within the subscription — superset of squad-derived players."""
    return _load_core(conn, "/players", "sportmonks__core_players")


# ── Global loaders ────────────────────────────────────────────────────────────

def load_types(conn) -> int:
    """Core API lookup table — always truncate + reload."""
    delete_global(conn, "sportmonks__types")
    records = get_paginated("/types", base=CORE_API_BASE)
    insert_batch(conn, "sportmonks__types", _rows(records))
    log.info("sportmonks__types: %d rows", len(records))
    return len(records)


def load_league(conn) -> dict:
    """Single league record — always truncate + reload."""
    delete_global(conn, "sportmonks__league")
    data = get(f"/leagues/{LEAGUE_ID}")["data"]
    insert_batch(conn, "sportmonks__league", [(data["id"], json.dumps(data), None, None)])
    log.info("sportmonks__league: id=%d", data["id"])
    return data


def load_seasons(conn) -> list:
    """All in-scope seasons — always truncate + reload. Returns season list."""
    delete_global(conn, "sportmonks__seasons")
    raw = get(f"/leagues/{LEAGUE_ID}", params={"include": "seasons"})["data"]["seasons"]
    seasons = sorted(
        [s for s in raw if int(s["name"][:4]) >= FIRST_SEASON_YEAR],
        key=lambda s: s["starting_at"],
    )
    insert_batch(conn, "sportmonks__seasons", _rows(seasons))
    log.info("sportmonks__seasons: %d rows (%s – %s)",
             len(seasons), seasons[0]["name"], seasons[-1]["name"])
    return seasons


# ── Seasonal loaders ──────────────────────────────────────────────────────────

def load_stages(conn, seasons: list) -> dict:
    """Returns {season_id: [stage, ...]} for downstream sub-loaders."""
    stage_map = {}
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__stages", sid)
        stages = get_paginated(f"/stages/seasons/{sid}")
        insert_batch(conn, "sportmonks__stages", _rows(stages, season_id=sid))
        stage_map[sid] = stages
        log.info("sportmonks__stages  %s: %d rows", season["name"], len(stages))
    return stage_map


def load_rounds(conn, seasons: list) -> dict:
    """Returns {season_id: [round, ...]} for downstream sub-loaders."""
    round_map = {}
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__rounds", sid)
        rounds = get_paginated(f"/rounds/seasons/{sid}")
        insert_batch(conn, "sportmonks__rounds", _rows(rounds, season_id=sid))
        round_map[sid] = rounds
        log.info("sportmonks__rounds  %s: %d rows", season["name"], len(rounds))
    return round_map


def load_teams(conn, seasons: list) -> dict:
    """Returns {season_id: [team, ...]} for squads, coaches, transfers, etc."""
    team_map = {}
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__teams", sid)
        teams = get_paginated(f"/teams/seasons/{sid}", {"include": "coaches;venue"})
        insert_batch(conn, "sportmonks__teams", _rows(teams, season_id=sid))
        team_map[sid] = teams
        log.info("sportmonks__teams   %s: %d rows", season["name"], len(teams))
    return team_map


def load_squads(conn, seasons: list, team_map: dict) -> int:
    """Player rosters — one row per squad entry (player × team × season)."""
    total = 0
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__squads", sid)
        teams = team_map.get(sid) or get_paginated(f"/teams/seasons/{sid}")
        rows = []
        for team in teams:
            players = get_paginated(
                f"/squads/seasons/{sid}/teams/{team['id']}",
                {"include": "player;position"},
            )
            rows.extend(_rows(players, season_id=sid))
        insert_batch(conn, "sportmonks__squads", rows)
        log.info("sportmonks__squads  %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


def load_venues(conn, seasons: list) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__venues", sid)
        records = get_paginated(f"/venues/seasons/{sid}")
        # deduplicate across seasons (same venue_id may appear in multiple seasons)
        seen = set()
        rows = [
            (r["id"], json.dumps(r), sid, None)
            for r in records if r["id"] not in seen and not seen.add(r["id"])
        ]
        insert_batch(conn, "sportmonks__venues", rows)
        log.info("sportmonks__venues  %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


def load_referees(conn, seasons: list) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__referees", sid)
        records = get_paginated(f"/referees/seasons/{sid}", {"include": "country"})
        seen = set()
        rows = [
            (r["id"], json.dumps(r), sid, None)
            for r in records if r["id"] not in seen and not seen.add(r["id"])
        ]
        insert_batch(conn, "sportmonks__referees", rows)
        log.info("sportmonks__referees %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


def load_standings(conn, seasons: list) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__standings", sid)
        records = get_paginated(
            f"/standings/seasons/{sid}",
            {"include": "participant;details;rule"},
        )
        insert_batch(conn, "sportmonks__standings", _rows(records, season_id=sid))
        log.info("sportmonks__standings %s: %d rows", season["name"], len(records))
        total += len(records)
    return total


def load_topscorers(conn, seasons: list) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, "sportmonks__topscorers", sid)
        records = get_paginated(
            f"/topscorers/seasons/{sid}",
            {"include": "player;participant;type"},
        )
        insert_batch(conn, "sportmonks__topscorers", _rows(records, season_id=sid))
        log.info("sportmonks__topscorers %s: %d rows", season["name"], len(records))
        total += len(records)
    return total


def load_stage_topscorers(conn, seasons: list, stage_map: dict) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        stages = stage_map.get(sid) or get_paginated(f"/stages/seasons/{sid}")
        delete_by_season(conn, "sportmonks__stage_topscorers", sid)
        rows, seen = [], set()
        for stage in stages:
            for r in get_paginated(f"/topscorers/stages/{stage['id']}",
                                   {"include": "player;participant;type"}):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, "sportmonks__stage_topscorers", rows)
        log.info("sportmonks__stage_topscorers %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


def load_stage_statistics(conn, seasons: list, stage_map: dict) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        stages = stage_map.get(sid) or get_paginated(f"/stages/seasons/{sid}")
        delete_by_season(conn, "sportmonks__stage_statistics", sid)
        rows, seen = [], set()
        for stage in stages:
            for r in get_paginated(f"/statistics/stages/{stage['id']}",
                                   {"include": "type"}):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, "sportmonks__stage_statistics", rows)
        log.info("sportmonks__stage_statistics %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


def load_round_statistics(conn, seasons: list, round_map: dict) -> int:
    total = 0
    for season in seasons:
        sid = season["id"]
        rounds = round_map.get(sid) or get_paginated(f"/rounds/seasons/{sid}")
        delete_by_season(conn, "sportmonks__round_statistics", sid)
        rows, seen = [], set()
        for rnd in rounds:
            for r in get_paginated(f"/statistics/rounds/{rnd['id']}",
                                   {"include": "type"}):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, "sportmonks__round_statistics", rows)
        log.info("sportmonks__round_statistics %s: %d rows", season["name"], len(rows))
        total += len(rows)
    return total


# ── Global team-based loaders ─────────────────────────────────────────────────

def load_coaches(conn, team_map: dict) -> int:
    """Full coaching history per team — always truncate + reload."""
    team_ids = _all_team_ids(team_map)
    delete_global(conn, "sportmonks__coaches")
    rows, seen = [], set()
    for team_id in sorted(team_ids):
        for r in get_paginated(f"/coaches/teams/{team_id}"):
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), None, None))
    insert_batch(conn, "sportmonks__coaches", rows)
    log.info("sportmonks__coaches: %d rows (%d teams)", len(rows), len(team_ids))
    return len(rows)


def load_transfers(conn, team_map: dict) -> int:
    """All transfers per team — always truncate + reload."""
    team_ids = _all_team_ids(team_map)
    delete_global(conn, "sportmonks__transfers")
    rows, seen = [], set()
    for team_id in sorted(team_ids):
        for r in get_paginated(f"/transfers/teams/{team_id}",
                               {"include": "player;fromTeam;toTeam;type"}):
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), None, None))
    insert_batch(conn, "sportmonks__transfers", rows)
    log.info("sportmonks__transfers: %d rows", len(rows))
    return len(rows)


def load_rivals(conn, team_map: dict) -> int:
    """Registered rival pairs per team — always truncate + reload."""
    team_ids = _all_team_ids(team_map)
    delete_global(conn, "sportmonks__rivals")
    rows, seen = [], set()
    for team_id in sorted(team_ids):
        for r in get_paginated(f"/rivals/teams/{team_id}"):
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), None, None))
    insert_batch(conn, "sportmonks__rivals", rows)
    log.info("sportmonks__rivals: %d rows", len(rows))
    return len(rows)


def load_h2h(conn, team_map: dict) -> int:
    """All pairwise H2H fixtures for every known team combination."""
    team_ids = sorted(_all_team_ids(team_map))
    pairs = list(itertools.combinations(team_ids, 2))
    delete_global(conn, "sportmonks__h2h")
    rows, seen = [], set()
    for t1, t2 in pairs:
        for r in get_paginated(f"/fixtures/head-to-head/{t1}/{t2}",
                               {"include": H2H_INCLUDES}):
            if r["id"] not in seen:
                seen.add(r["id"])
                fd = (r.get("starting_at") or "")[:10] or None
                rows.append((r["id"], json.dumps(r), None, fd))
    insert_batch(conn, "sportmonks__h2h", rows)
    log.info("sportmonks__h2h: %d rows (%d pairs)", len(rows), len(pairs))
    return len(rows)


# ── Fixture loaders ───────────────────────────────────────────────────────────

def _load_fixture_window(conn, from_date: str, to_date: str) -> int:
    try:
        records = get_paginated(
            f"/fixtures/between/{from_date}/{to_date}",
            {"include": FIXTURE_INCLUDES},
        )
    except requests.HTTPError as exc:
        if exc.response is not None and exc.response.status_code == 400:
            log.info("fixtures %s → %s: empty window (400)", from_date, to_date)
            return 0
        raise

    fixtures = [f for f in records if f.get("league_id") == LEAGUE_ID]
    rows = [
        (f["id"], json.dumps(f), f.get("season_id"), (f.get("starting_at") or "")[:10] or None)
        for f in fixtures
    ]
    insert_batch(conn, "sportmonks__fixtures", rows)
    log.info("fixtures %s → %s: %d inserted (%d fetched, %d other leagues)",
             from_date, to_date, len(rows), len(records), len(records) - len(rows))
    return len(rows)


def load_fixtures_full(conn, seasons: list) -> int:
    """Full historical load: iterate every season in 90-day windows."""
    total = 0
    for season in seasons:
        start = date.fromisoformat(season["starting_at"])
        end   = date.fromisoformat(season["ending_at"])
        for from_date, to_date in _date_chunks(start, end):
            delete_by_date(conn, "sportmonks__fixtures", from_date, to_date)
            total += _load_fixture_window(conn, from_date, to_date)
    log.info("fixtures full load complete: %d total", total)
    return total


def load_fixtures_incremental(conn) -> int:
    """Daily refresh: delete and reload the last INCREMENTAL_DAYS days."""
    from_date = (date.today() - timedelta(days=INCREMENTAL_DAYS)).isoformat()
    to_date   = date.today().isoformat()
    delete_by_date(conn, "sportmonks__fixtures", from_date, to_date)
    n = _load_fixture_window(conn, from_date, to_date)
    log.info("fixtures incremental complete: %d rows (%s → %s)", n, from_date, to_date)
    return n
