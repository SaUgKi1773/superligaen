import os

API_BASE      = "https://api.sportmonks.com/v3/football"
CORE_API_BASE = "https://api.sportmonks.com/v3/core"

LEAGUE_ID         = 271
FIRST_SEASON_YEAR = 2010
MAX_RETRIES       = 5
PER_PAGE          = 100
DATE_CHUNK_DAYS   = 90   # stay under the 100-day API window limit
INCREMENTAL_DAYS  = 30   # how far back the daily refresh looks

# All includes confirmed available on the free plan via API probe + official docs
FIXTURE_INCLUDES = (
    "scores;participants;venue;round;state;"
    "events;timeline;statistics;referees.referee;periods;"
    "lineups;lineups.details;coaches;formations;sidelined;weatherreport"
)

# Lighter include set for H2H (historical, no lineup/weather needed)
H2H_INCLUDES = "scores;participants;state;referees.referee"

_PROJECT_ROOT   = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DB_PATH = os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")
