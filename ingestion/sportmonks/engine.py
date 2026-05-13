"""
Metadata-driven ingestion engine for Sportmonks v3 bronze layer.

Reads ENDPOINT_MANIFEST from config.py and dispatches each entry to the
appropriate strategy handler.  No hard-coded loader functions exist here —
adding an entry to the manifest is all that is needed to ingest a new endpoint.

Every table is loaded on every run (full and incremental).  The delete strategy
in the manifest — not the run mode — controls the refresh granularity:

  global      → full truncate + reload the entire table
  seasonal    → delete current season rows, reload; prior seasons untouched
  date_window → delete rolling window rows, reload; other dates untouched

The only behavioural difference between modes is scope for seasonal / date entries:
  full        → seasonal entries cover ALL in-scope seasons;
                date_based iterates 90-day chunks across every season's range
  incremental → seasonal entries cover CURRENT season only;
                date_based uses a rolling ±3 / +30 day window around today

Strategy handlers
-----------------
static              → single paginated call
seasons_from_league → bootstrap: extracts seasons[] from league JSON;
                      populates ctx.all_seasons + ctx.current_seasons
season_based        → iterate each season_id (scope depends on mode)
season_team_based   → iterate each (season_id, team_id) pair
stage_based         → iterate each stage_id per season
round_based         → iterate each round_id per season
team_based          → iterate ALL historical team IDs (current load + DB);
                      always covers every team regardless of run mode
pair_based          → every unique (team1_id, team2_id) combination (H2H)
date_based          → season-range chunks (full) or rolling window (incremental)
"""

import itertools
import json
import logging
from datetime import date, timedelta

import requests

from api import get, get_paginated
from config import (
    API_BASE,
    DATE_CHUNK_DAYS,
    ENDPOINT_MANIFEST,
    FIRST_SEASON_YEAR,
    INCREMENTAL_DAYS_BACK,
    INCREMENTAL_DAYS_FORWARD,
    LEAGUE_ID,
)
from db import delete_global, delete_by_season, delete_by_date, insert_batch

log = logging.getLogger(__name__)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _rows(records, season_id=None, date_fn=None):
    return [
        (r["id"], json.dumps(r), season_id, date_fn(r) if date_fn else None)
        for r in records
    ]


def _date_chunks(start: date, end: date, days: int = DATE_CHUNK_DAYS):
    cursor = start
    while cursor <= end:
        yield cursor.isoformat(), min(cursor + timedelta(days=days - 1), end).isoformat()
        cursor += timedelta(days=days)


def _all_team_ids(team_map: dict) -> set:
    return {t["id"] for teams in team_map.values() for t in teams}


def _resolve_all_team_ids(conn, team_map: dict) -> set:
    """
    Return the union of team IDs from team_map (just-loaded seasons) and every
    row already stored in bronze.sportmonks__teams (from previous runs).
    This ensures that in incremental mode — where team_map only contains the
    current season — team_based loaders still cover all historical teams and
    don't wipe prior-season data from coaches / transfers / rivals / h2h.
    """
    ids = _all_team_ids(team_map)
    try:
        rows = conn.execute(
            "SELECT DISTINCT id FROM bronze.sportmonks__teams"
        ).fetchall()
        ids |= {row[0] for row in rows}
    except Exception:
        pass  # table not yet created on the very first run
    return ids


def _params(entry: dict) -> dict:
    p = {}
    if entry.get("includes"):
        p["include"] = entry["includes"]
    if entry.get("extra_params"):
        p.update(entry["extra_params"])
    return p


def _base(entry: dict) -> str:
    return entry.get("base", API_BASE)


# ── Context ────────────────────────────────────────────────────────────────────

class _Context:
    """Runtime state built up as the engine walks the manifest in order."""
    def __init__(self):
        self.all_seasons: list = []      # all in-scope seasons (>= FIRST_SEASON_YEAR)
        self.current_seasons: list = []  # seasons where is_current=True (or latest)
        self.stage_map: dict = {}        # {season_id: [stage, ...]}
        self.round_map: dict = {}        # {season_id: [round, ...]}
        self.team_map: dict = {}         # {season_id: [team, ...]}  (mode-scoped)
        self.all_team_ids: set = set()   # ALL historical team IDs (DB + current load)


# ── Strategy handlers ──────────────────────────────────────────────────────────

def _handle_static(conn, entry: dict, _ctx: _Context) -> int:
    delete_global(conn, entry["table"])
    records = get_paginated(entry["path"], _params(entry), _base(entry))
    insert_batch(conn, entry["table"], _rows(records))
    log.info("%-46s %d rows", entry["table"] + ":", len(records))
    return len(records)


def _handle_seasons_from_league(conn, entry: dict, ctx: _Context) -> list:
    """
    Fetch the league record with include=seasons, extract the seasons[] array,
    filter by FIRST_SEASON_YEAR, persist, and populate ctx.all_seasons /
    ctx.current_seasons so season-based entries can iterate correctly.
    """
    delete_global(conn, entry["table"])
    raw = get(entry["path"], {"include": "seasons"}, _base(entry))["data"]["seasons"]
    seasons = sorted(
        [s for s in raw if int(s["name"][:4]) >= FIRST_SEASON_YEAR],
        key=lambda s: s["starting_at"],
    )
    insert_batch(conn, entry["table"], _rows(seasons))

    ctx.all_seasons = seasons
    ctx.current_seasons = [s for s in seasons if s.get("is_current")]
    if not ctx.current_seasons:
        ctx.current_seasons = [max(seasons, key=lambda s: s["starting_at"])]

    log.info("%-46s %d rows (%s – %s)",
             entry["table"] + ":", len(seasons),
             seasons[0]["name"], seasons[-1]["name"])
    log.info("current season(s): %s", [s["name"] for s in ctx.current_seasons])
    return seasons


def _handle_season_based(conn, entry: dict, seasons: list, _ctx: _Context) -> dict:
    """
    Iterate each season and call the paginated endpoint.
    Returns {season_id: [record, ...]} so the caller can update context maps.
    Deduplicates within each season call (same ID can occasionally appear twice
    when the API paginates an edge-case boundary).
    """
    result_map = {}
    for season in seasons:
        sid = season["id"]
        delete_by_season(conn, entry["table"], sid)
        records = get_paginated(
            entry["path"].format(season_id=sid),
            _params(entry),
            _base(entry),
        )
        seen, rows = set(), []
        for r in records:
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, entry["table"], rows)
        result_map[sid] = records
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
    return result_map


def _handle_season_team_based(conn, entry: dict, seasons: list, ctx: _Context) -> int:
    """Iterate every (season × team) pair; used for squad rosters."""
    total = 0
    for season in seasons:
        sid = season["id"]
        teams = ctx.team_map.get(sid) or get_paginated(
            f"/teams/seasons/{sid}", base=API_BASE
        )
        delete_by_season(conn, entry["table"], sid)
        rows = []
        for team in teams:
            records = get_paginated(
                entry["path"].format(season_id=sid, team_id=team["id"]),
                _params(entry),
                _base(entry),
            )
            rows.extend(_rows(records, season_id=sid))
        insert_batch(conn, entry["table"], rows)
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
        total += len(rows)
    return total


def _handle_stage_based(conn, entry: dict, seasons: list, ctx: _Context) -> int:
    """Iterate each stage within each season; deduplicates across stages."""
    total = 0
    for season in seasons:
        sid = season["id"]
        stages = ctx.stage_map.get(sid) or get_paginated(
            f"/stages/seasons/{sid}", base=API_BASE
        )
        delete_by_season(conn, entry["table"], sid)
        rows, seen = [], set()
        for stage in stages:
            for r in get_paginated(
                entry["path"].format(stage_id=stage["id"]),
                _params(entry),
                _base(entry),
            ):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, entry["table"], rows)
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
        total += len(rows)
    return total


def _handle_round_based(conn, entry: dict, seasons: list, ctx: _Context) -> int:
    """Iterate each round within each season; deduplicates across rounds."""
    total = 0
    for season in seasons:
        sid = season["id"]
        rounds = ctx.round_map.get(sid) or get_paginated(
            f"/rounds/seasons/{sid}", base=API_BASE
        )
        delete_by_season(conn, entry["table"], sid)
        rows, seen = [], set()
        for rnd in rounds:
            for r in get_paginated(
                entry["path"].format(round_id=rnd["id"]),
                _params(entry),
                _base(entry),
            ):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None))
        insert_batch(conn, entry["table"], rows)
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
        total += len(rows)
    return total


def _handle_team_based(conn, entry: dict, ctx: _Context) -> int:
    """Iterate all unique team IDs across every season; deduplicates entities."""
    team_ids = ctx.all_team_ids
    delete_global(conn, entry["table"])
    rows, seen = [], set()
    for team_id in sorted(team_ids):
        for r in get_paginated(
            entry["path"].format(team_id=team_id),
            _params(entry),
            _base(entry),
        ):
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), None, None))
    insert_batch(conn, entry["table"], rows)
    log.info("%-46s %d rows (%d teams)", entry["table"] + ":", len(rows), len(team_ids))
    return len(rows)


def _handle_pair_based(conn, entry: dict, ctx: _Context) -> int:
    """Iterate all unique unordered team pairs for H2H data."""
    team_ids = sorted(ctx.all_team_ids)
    pairs = list(itertools.combinations(team_ids, 2))
    delete_global(conn, entry["table"])
    rows, seen = [], set()
    for t1, t2 in pairs:
        for r in get_paginated(
            entry["path"].format(team1_id=t1, team2_id=t2),
            _params(entry),
            _base(entry),
        ):
            if r["id"] not in seen:
                seen.add(r["id"])
                fd = (r.get("starting_at") or "")[:10] or None
                rows.append((r["id"], json.dumps(r), None, fd))
    insert_batch(conn, entry["table"], rows)
    log.info("%-46s %d rows (%d pairs)", entry["table"] + ":", len(rows), len(pairs))
    return len(rows)


def _fetch_fixture_window(conn, entry: dict, from_date: str, to_date: str) -> int:
    """
    Fetch one date window, filter to LEAGUE_ID client-side (the API's leagueIds
    param is unreliable on the between-dates endpoint), and upsert.
    Returns 400 from the API if the window is empty — treated as zero rows.
    """
    try:
        records = get_paginated(
            entry["path"].format(from_date=from_date, to_date=to_date),
            _params(entry),
            _base(entry),
        )
    except requests.HTTPError as exc:
        if exc.response is not None and exc.response.status_code == 400:
            return 0
        raise

    fixtures = [f for f in records if f.get("league_id") == LEAGUE_ID]
    rows = [
        (f["id"], json.dumps(f), f.get("season_id"),
         (f.get("starting_at") or "")[:10] or None)
        for f in fixtures
    ]
    insert_batch(conn, entry["table"], rows)
    log.info("%-46s %s → %s  %d rows (%d other-league filtered)",
             entry["table"] + ":", from_date, to_date,
             len(rows), len(records) - len(rows))
    return len(rows)


def _handle_date_based_full(conn, entry: dict, ctx: _Context) -> int:
    """Full load: iterate 90-day chunks across every season's date range."""
    total = 0
    for season in ctx.all_seasons:
        start = date.fromisoformat(season["starting_at"])
        end   = date.fromisoformat(season["ending_at"])
        for from_date, to_date in _date_chunks(start, end):
            delete_by_date(conn, entry["table"], from_date, to_date)
            total += _fetch_fixture_window(conn, entry, from_date, to_date)
    log.info("%-46s full load complete: %d rows", entry["table"] + ":", total)
    return total


def _handle_date_based_incremental(conn, entry: dict, _ctx: _Context) -> int:
    """Incremental load: delete-and-reload a rolling past+future window."""
    from_date = (date.today() - timedelta(days=INCREMENTAL_DAYS_BACK)).isoformat()
    to_date   = (date.today() + timedelta(days=INCREMENTAL_DAYS_FORWARD)).isoformat()
    delete_by_date(conn, entry["table"], from_date, to_date)
    n = _fetch_fixture_window(conn, entry, from_date, to_date)
    log.info("%-46s incremental: %d rows (%s → %s)",
             entry["table"] + ":", n, from_date, to_date)
    return n


# ── Dispatch ───────────────────────────────────────────────────────────────────

def _dispatch(conn, entry: dict, ctx: _Context, mode: str) -> None:
    strategy = entry["strategy"]
    # Seasonal entries use all seasons in full mode, current season(s) in incremental
    seasons = ctx.all_seasons if mode == "full" else ctx.current_seasons

    if strategy == "static":
        _handle_static(conn, entry, ctx)

    elif strategy == "seasons_from_league":
        _handle_seasons_from_league(conn, entry, ctx)

    elif strategy == "season_based":
        result = _handle_season_based(conn, entry, seasons, ctx)
        # Update context maps for entries that drive downstream iteration
        key = entry.get("context_key")
        if key == "stage_map":
            ctx.stage_map.update(result)
        elif key == "round_map":
            ctx.round_map.update(result)
        elif key == "team_map":
            ctx.team_map.update(result)
            # Supplement with every team ID ever stored in the DB so that
            # team_based entries (coaches, transfers, rivals, h2h) cover all
            # historical teams even when running in incremental mode.
            ctx.all_team_ids = _resolve_all_team_ids(conn, ctx.team_map)

    elif strategy == "season_team_based":
        _handle_season_team_based(conn, entry, seasons, ctx)

    elif strategy == "stage_based":
        _handle_stage_based(conn, entry, seasons, ctx)

    elif strategy == "round_based":
        _handle_round_based(conn, entry, seasons, ctx)

    elif strategy == "team_based":
        _handle_team_based(conn, entry, ctx)

    elif strategy == "pair_based":
        _handle_pair_based(conn, entry, ctx)

    elif strategy == "date_based":
        if mode == "full":
            _handle_date_based_full(conn, entry, ctx)
        else:
            _handle_date_based_incremental(conn, entry, ctx)

    else:
        log.warning("Unknown strategy %r for %s — skipped", strategy, entry["table"])


# ── Public entry points ────────────────────────────────────────────────────────

def run(conn, mode: str = "incremental") -> None:
    """
    Execute the full ingestion pipeline driven by ENDPOINT_MANIFEST.

    Every table is loaded in both modes.  The delete strategy per entry
    determines how much data is replaced:

    mode "full"        — all seasons iterated for seasonal tables;
                         full season-range chunks for fixtures
    mode "incremental" — current season only for seasonal tables;
                         rolling ±3 / +30 day window for fixtures
    """
    if mode not in ("full", "incremental"):
        raise ValueError(f"mode must be 'full' or 'incremental', got {mode!r}")

    log.info("=== %s LOAD START ===", mode.upper())

    ctx = _Context()
    active = [e for e in ENDPOINT_MANIFEST if mode in e.get("modes", ["full"])]

    for entry in active:
        try:
            _dispatch(conn, entry, ctx, mode)
        except Exception as exc:
            log.error("FAILED  %s  (%s): %s", entry["table"], entry["strategy"], exc)
            raise

    log.info("=== %s LOAD COMPLETE ===", mode.upper())
