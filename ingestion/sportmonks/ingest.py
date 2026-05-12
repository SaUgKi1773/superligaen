"""
Generic scope-based loaders. Each function accepts an endpoint config list:
    {"table": "sportmonks__foo", "path": "/foo/{param}"}

Scopes
------
season      path contains {season_id}
stage       path contains {stage_id}   — stages fetched per season
round       path contains {round_id}   — rounds fetched per season
team        path contains {team_id}    — teams collected across seasons
team_pair   path contains {team1_id}/{team2_id}
"""

import itertools
import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def _params(ep: dict) -> dict | None:
    inc = ep.get("includes")
    return {"include": inc} if inc else None


def load_season_endpoints(conn, seasons, endpoints):
    for ep in endpoints:
        seen, total = set(), 0
        for season in seasons:
            path = ep["path"].format(season_id=season["id"])
            for r in get_paginated(path, _params(ep)):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, ep["table"], r["id"], r, f"sportmonks{path}")
                    total += 1
        log.info("%s: %d upserted", ep["table"], total)


def load_stage_endpoints(conn, seasons, endpoints):
    for ep in endpoints:
        seen, total = set(), 0
        for season in seasons:
            for stage in get_paginated(f"/stages/seasons/{season['id']}"):
                path = ep["path"].format(stage_id=stage["id"])
                for r in get_paginated(path, _params(ep)):
                    if r["id"] not in seen:
                        seen.add(r["id"])
                        upsert(conn, ep["table"], r["id"], r, f"sportmonks{path}")
                        total += 1
        log.info("%s: %d upserted", ep["table"], total)


def load_round_endpoints(conn, seasons, endpoints):
    for ep in endpoints:
        seen, total = set(), 0
        for season in seasons:
            for rnd in get_paginated(f"/rounds/seasons/{season['id']}"):
                path = ep["path"].format(round_id=rnd["id"])
                for r in get_paginated(path, _params(ep)):
                    if r["id"] not in seen:
                        seen.add(r["id"])
                        upsert(conn, ep["table"], r["id"], r, f"sportmonks{path}")
                        total += 1
        log.info("%s: %d upserted", ep["table"], total)


def _collect_team_ids(seasons):
    team_ids = set()
    for season in seasons:
        for t in get_paginated(f"/teams/seasons/{season['id']}"):
            team_ids.add(t["id"])
    return team_ids


def load_team_endpoints(conn, seasons, endpoints):
    team_ids = _collect_team_ids(seasons)
    for ep in endpoints:
        seen, total = set(), 0
        for team_id in sorted(team_ids):
            path = ep["path"].format(team_id=team_id)
            for r in get_paginated(path, _params(ep)):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, ep["table"], r["id"], r, f"sportmonks{path}")
                    total += 1
        log.info("%s: %d upserted", ep["table"], total)


def load_team_pair_endpoints(conn, seasons, endpoints):
    team_ids = _collect_team_ids(seasons)
    pairs = list(itertools.combinations(sorted(team_ids), 2))
    log.info("Team pairs: %d teams → %d pairs", len(team_ids), len(pairs))
    for ep in endpoints:
        seen, total = set(), 0
        for team1, team2 in pairs:
            path = ep["path"].format(team1_id=team1, team2_id=team2)
            for r in get_paginated(path, _params(ep)):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    upsert(conn, ep["table"], r["id"], r, f"sportmonks{path}")
                    total += 1
        log.info("%s: %d upserted", ep["table"], total)
