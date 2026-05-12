import os

API_BASE         = "https://api.sportmonks.com/v3/football"
LEAGUE_ID        = 271
FIRST_SEASON_YEAR = 2010   # 2010/2011 onwards — filter by starting year in season name
MAX_RETRIES      = 5
PER_PAGE         = 100
DATE_CHUNK_DAYS  = 90      # stay under the 100-day API limit

FIXTURE_INCLUDES = (
    "scores;participants;venue;round;state;"
    "events;statistics;referees.referee;periods"
)

# Resolved at runtime — two levels up from this file (project root)
_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DB_PATH = os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")
