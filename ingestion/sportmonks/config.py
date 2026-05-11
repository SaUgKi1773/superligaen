"""
Pipeline configuration — single source of truth for leagues, seasons, and API metadata.

Sportmonks free plan covers:
  - Danish Superliga (league 271)  +  Superliga Play-offs (league 1659)
  - Scottish Premiership (league 501)  +  Premiership Play-offs (league 513)

We ingest Danish Superliga only.
"""

API_BASE    = "https://api.sportmonks.com/v3/football"
MAX_RETRIES = 7
FIRST_SEASON_ID = 17328  # 2020/2021 — earlier seasons loaded on demand

# ---------------------------------------------------------------------------
# League
# ---------------------------------------------------------------------------

LEAGUE_ID  = 271   # Danish Superliga
COUNTRY_ID = 320   # Denmark

# ---------------------------------------------------------------------------
# Fixture includes — fetched in a single call per fixture
# ---------------------------------------------------------------------------

FIXTURE_INCLUDES = "events;statistics;lineups;participants;scores;state;referees"

# ---------------------------------------------------------------------------
# Bronze table names
# ---------------------------------------------------------------------------

# Static / reference — full refresh each run
TBL_LEAGUES    = "sportmonks__leagues"
TBL_SEASONS    = "sportmonks__seasons"
TBL_TEAMS      = "sportmonks__teams"
TBL_VENUES     = "sportmonks__venues"
TBL_REFEREES   = "sportmonks__referees"
TBL_ROUNDS     = "sportmonks__rounds"

# Season-level — full refresh for current season
TBL_STANDINGS  = "sportmonks__standings"
TBL_TOPSCORERS = "sportmonks__topscorers"

# Fixture-level — incremental by date
TBL_FIXTURES         = "sportmonks__fixtures"
TBL_FIXTURE_EVENTS   = "sportmonks__fixture_events"
TBL_FIXTURE_STATS    = "sportmonks__fixture_statistics"
TBL_FIXTURE_LINEUPS  = "sportmonks__fixture_lineups"
TBL_FIXTURE_REFEREES = "sportmonks__fixture_referees"

STATIC_TABLES   = [TBL_LEAGUES, TBL_SEASONS, TBL_TEAMS, TBL_VENUES, TBL_REFEREES, TBL_ROUNDS]
SEASON_TABLES   = [TBL_STANDINGS, TBL_TOPSCORERS]
FIXTURE_TABLES  = [TBL_FIXTURES, TBL_FIXTURE_EVENTS, TBL_FIXTURE_STATS, TBL_FIXTURE_LINEUPS, TBL_FIXTURE_REFEREES]
ALL_TABLES      = STATIC_TABLES + SEASON_TABLES + FIXTURE_TABLES
