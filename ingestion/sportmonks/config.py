import os

API_BASE      = "https://api.sportmonks.com/v3/football"
CORE_API_BASE = "https://api.sportmonks.com/v3/core"

LEAGUE_ID         = 271
FIRST_SEASON_YEAR = 2010
MAX_RETRIES       = 8
REQUEST_TIMEOUT   = 120  # seconds per HTTP request
PER_PAGE          = 100
DATE_CHUNK_DAYS   = 90   # stay under the ~100-day API window limit
API_CALL_DELAY    = 1.0  # seconds between every API request (rate-limit throttle)
INCREMENTAL_DAYS_BACK    = 3
INCREMENTAL_DAYS_FORWARD = 30

_PROJECT_ROOT   = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DB_PATH = os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")

# ── Free-plan blocked endpoints (return HTTP 403) ──────────────────────────────
# Do not add these to the manifest — they will always fail on the current plan:
#   trends, xGFixture, pressure, expectedLineups, premiumOdds, inplayOdds,
#   highlights, predictions, ballCoordinates, prematchNews, postmatchNews
#
# API quirks to keep in mind when extending the manifest:
#   - Pagination: per_page max 100; API returns HTTP 400 past the last page
#     (not a real error — api.py treats it as the stop signal)
#   - Fixture date-range endpoint: max ~100 days per window → use 90-day chunks
#   - Fixture date-range endpoint: ignores the leagueIds query param →
#     filter client-side on league_id == LEAGUE_ID

# ── Master Endpoint Manifest ────────────────────────────────────────────────────
#
# Each entry drives the generic engine (engine.py).  No hand-written loader
# functions are needed — add a row here and the engine handles the rest.
#
# Fields
# ------
# table     : bronze table name  (stored under bronze.<table>)
# path      : API path template; may contain {season_id}, {team_id}, {stage_id},
#             {round_id}, {team1_id}/{team2_id}, {from_date}/{to_date}
# base      : optional URL base (defaults to API_BASE = football API)
# strategy  : iteration pattern — see values below
# delete    : how the table is cleared before each reload
# includes  : semicolon-joined include string sent as ?include=
#             Contains ALL documented 'Available Includes' for this entity.
# context_key : if set, engine caches the loaded records under this context key
#               (used by later entries that need stage_map / round_map / team_map)
# modes     : which run modes activate this entry — all entries currently run in
#             both "full" and "incremental".  The delete strategy (not modes) is
#             what determines the refresh granularity on each run.
#
# Strategies
# ----------
# static            → single paginated call; path used verbatim
# seasons_from_league → extract seasons[] nested in the league response;
#                       populates ctx.all_seasons + ctx.current_seasons
# season_based      → loop over seasons; path gets {season_id}
# season_team_based → loop over (season × team); path gets {season_id}, {team_id}
# stage_based       → loop over stages per season; path gets {stage_id}
# round_based       → loop over rounds per season; path gets {round_id}
# team_based        → loop over all unique team_ids; path gets {team_id}
# pair_based        → all unique (team1, team2) pairs; path gets {team1_id}, {team2_id}
# date_based        → date-chunk iteration across season ranges (full) or rolling
#                     window (incremental); path gets {from_date}, {to_date}
#
# Delete strategies
# -----------------
# global      → DELETE FROM table (full truncate)
# seasonal    → DELETE WHERE _season_id = ?
# date_window → DELETE WHERE _fixture_date BETWEEN ? AND ?
#

ENDPOINT_MANIFEST = [

    # ══════════════════════════════════════════════════════════════════════════
    # CORE API  (reference / geography)
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":    "sportmonks__core_continents",
        "path":     "/continents",
        "base":     CORE_API_BASE,
        "strategy": "static",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__core_countries",
        "path":     "/countries",
        "base":     CORE_API_BASE,
        "strategy": "static",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },
    {
        "table":        "sportmonks__core_regions",
        "path":         "/regions",
        "base":         CORE_API_BASE,
        "strategy":     "static",
        "delete":       "global",
        "includes":     "",
        # Filter to Denmark only — global dataset is 3000+ rows across all countries
        "extra_params": {"filters": "regionCountries:320"},
        "modes":        ["full", "incremental"],
    },
    # core_cities excluded — the API ignores the country_id filter param,
    # returning the full global dataset (100k+ cities). No viable way to
    # scope to Denmark without a working server-side filter.

    {
        "table":    "sportmonks__types",
        # Lookup table for every type_id referenced in other tables
        "path":     "/types",
        "base":     CORE_API_BASE,
        "strategy": "static",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__states",
        # Match state reference (Not Started, HT, FT, etc.)
        "path":     "/states",
        "strategy": "static",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__tv_stations",
        "path":     "/tv-stations",
        "strategy": "static",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTBALL API — League & Seasons  (bootstrap — must run before seasonal entries)
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":    "sportmonks__league",
        "path":     f"/leagues/{LEAGUE_ID}",
        "strategy": "static",
        "delete":   "global",
        "includes": "sport;country;stages;currentSeason;seasons",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__seasons",
        # Extracts the seasons[] array from the league response and filters by
        # FIRST_SEASON_YEAR.  Also populates ctx.all_seasons / ctx.current_seasons
        # so subsequent season_based entries know which seasons to iterate.
        "path":     f"/leagues/{LEAGUE_ID}",
        "strategy": "seasons_from_league",
        "delete":   "global",
        "includes": "",
        "modes":    ["full", "incremental"],
    },

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTBALL API — Players  (delete: global)
    # Subscription-scoped; provides positions, transfers, statistics etc.
    # Full truncate + reload on every run.
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":    "sportmonks__players",
        "path":     "/players",
        "strategy": "static",
        "delete":   "global",
        "includes": (
            "sport;country;city;nationality;"
            "transfers;pendingTransfers;teams;"
            "statistics;position;detailedPosition;trophies;metadata"
        ),
        "modes":    ["full", "incremental"],
    },

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTBALL API — Seasonal tables  (delete: seasonal)
    # full        → iterates ALL in-scope seasons
    # incremental → iterates CURRENT season only; prior seasons are untouched
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":       "sportmonks__stages",
        "path":        "/stages/seasons/{season_id}",
        "strategy":    "season_based",
        "delete":      "seasonal",
        "includes":    "league;season;type;rounds;currentRound;topscorers;statistics",
        # stage_map built here is consumed by stage_topscorers / stage_statistics below
        "context_key": "stage_map",
        "modes":       ["full", "incremental"],
    },
    {
        "table":       "sportmonks__rounds",
        "path":        "/rounds/seasons/{season_id}",
        "strategy":    "season_based",
        "delete":      "seasonal",
        "includes":    "sport;league;season;stage;fixtures;statistics",
        "context_key": "round_map",
        "modes":       ["full", "incremental"],
    },
    {
        "table":       "sportmonks__teams",
        "path":        "/teams/seasons/{season_id}",
        "strategy":    "season_based",
        "delete":      "seasonal",
        "includes":    "sport;country;venue;coaches;rivals;activeSeasons;statistics",
        # team_map built here drives rivals below and populates ctx.all_team_ids
        "context_key": "team_map",
        "modes":       ["full", "incremental"],
    },
    {
        "table":    "sportmonks__venues",
        "path":     "/venues/seasons/{season_id}",
        "strategy": "season_based",
        "delete":   "seasonal",
        "includes": "country;city",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__referees",
        "path":     "/referees/seasons/{season_id}",
        "strategy": "season_based",
        "delete":   "seasonal",
        "includes": "sport;country;statistics;nationality;city",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__standings",
        "path":     "/standings/seasons/{season_id}",
        "strategy": "season_based",
        "delete":   "seasonal",
        "includes": "participant;details;rule;form;season;league;stage;group;round",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__topscorers",
        "path":     "/topscorers/seasons/{season_id}",
        "strategy": "season_based",
        "delete":   "seasonal",
        "includes": "player;participant;type;season;stage",
        "modes":    ["full", "incremental"],
    },

    # Sub-season aggregates (driven by stage_map / round_map populated above)
    {
        "table":    "sportmonks__stage_topscorers",
        "path":     "/topscorers/stages/{stage_id}",
        "strategy": "stage_based",
        "delete":   "seasonal",
        "includes": "player;participant;type;season;stage",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__stage_statistics",
        "path":     "/statistics/stages/{stage_id}",
        "strategy": "stage_based",
        "delete":   "seasonal",
        "includes": "type;participant",
        "modes":    ["full", "incremental"],
    },
    {
        "table":    "sportmonks__round_statistics",
        "path":     "/statistics/rounds/{round_id}",
        "strategy": "round_based",
        "delete":   "seasonal",
        "includes": "type;participant",
        "modes":    ["full", "incremental"],
    },

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTBALL API — Team-based global tables  (delete: global)
    # Full truncate + reload on every run (full and incremental).
    # The engine resolves team IDs from the DB so all historical teams are
    # covered even when only the current season was fetched this run.
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":         "sportmonks__transfers",
        "path":          "/transfers/between/{from_date}/{to_date}",
        "strategy":      "date_based",
        "delete":        "date_window",
        "includes":      "sport;player;type;fromTeam;toTeam;position;detailedPosition",
        "league_filter": False,
        "date_field":    "date",
        "days_back":     30,   # wider window — transfers can lag weeks
        "days_forward":  0,    # no future dates — API rejects them
        "modes":         ["full", "incremental"],
    },
    {
        "table":    "sportmonks__rivals",
        "path":     "/rivals/teams/{team_id}",
        "strategy": "team_based",
        "delete":   "global",
        "includes": "team;rival",
        "modes":    ["full", "incremental"],
    },

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTBALL API — Fixtures  (date-window; 90-day chunks or rolling window)
    # Fetches all leagues in each window, filters to LEAGUE_ID client-side
    # (the API's leagueIds param is unreliable on the date-range endpoint).
    # ══════════════════════════════════════════════════════════════════════════

    {
        "table":    "sportmonks__fixtures",
        "path":     "/fixtures/between/{from_date}/{to_date}",
        "strategy": "date_based",
        "delete":   "date_window",
        "includes": (
            # Scores + sub-entities
            "scores;scores.type;scores.participant;scores.fixture;"
            # Core match context
            "participants;venue;round;stage;group;aggregate;state;"
            "sport;league;season;"
            # Events + all sub-entities
            "events;events.type;events.player;events.relatedPlayer;"
            "events.participant;events.subType;events.period;events.fixture;"
            # Timeline, statistics, metadata, commentary, broadcasting
            "timeline;statistics;metadata;comments;tvStations;"
            # Referees  (coaches is undocumented but confirmed via API probe)
            "referees.referee;coaches;"
            # Periods + all sub-entities
            "periods;periods.type;periods.statistics;periods.events;"
            "periods.timeline;periods.fixture;"
            # Lineups + all sub-entities (details = per-player match stats)
            "lineups;lineups.player;lineups.position;lineups.type;"
            "lineups.detailedPosition;lineups.details;lineups.fixture;"
            # Formations + sub-entities
            "formations;formations.participant;formations.fixture;"
            # Absent players and weather
            "sidelined;weatherReport"
            # Blocked on free plan — do not add:
            # trends, odds, premiumOdds, inplayOdds, prematchNews,
            # postmatchNews, predictions, ballCoordinates
        ),
        "modes":    ["full", "incremental"],
    },

]
