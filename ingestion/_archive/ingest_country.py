"""
Group 5: Country endpoints.
Filter: country (read from bronze.api_football__leagues after Group 1 runs)

Catch-all for endpoints filtered by country rather than league_id or season.
Currently covers venues. Add new country-filtered endpoints to
COUNTRY_ENDPOINTS in config.py.

Load strategy (all modes): DELETE by league_id + INSERT — always fully refreshed.
"""

import logging

from api import api_get
from config import COUNTRY_ENDPOINTS
from db import _delete_insert

log = logging.getLogger(__name__)


def load_country(conn, league_id: int, country: str) -> None:
    log.info("League %d: loading country data (country: %s)", league_id, country)
    for table, endpoint in COUNTRY_ENDPOINTS:
        try:
            data = api_get(endpoint, {"country": country})["response"]
            _delete_insert(conn, table, ["league_id"], [league_id], data)
        except Exception as exc:
            log.warning("Failed %s league %d country %s: %s", table, league_id, country, exc)
