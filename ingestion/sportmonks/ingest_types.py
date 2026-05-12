"""
Fetch all type definitions from the Sportmonks core API.
Types decode type_id values used across statistics, events, standings, scores, etc.
Lives under /v3/core/types, not /v3/football/.
"""

import logging
import os

import requests
from dotenv import load_dotenv

from db import upsert

load_dotenv()
log = logging.getLogger(__name__)

CORE_URL = "https://api.sportmonks.com/v3/core/types"


def load_types(conn) -> None:
    headers = {"Authorization": os.environ["SPORTMONKS_API_KEY"]}
    records, page = [], 1
    while True:
        r = requests.get(CORE_URL, headers=headers, params={"per_page": 100, "page": page}, timeout=30)
        r.raise_for_status()
        data = r.json()
        batch = data.get("data", [])
        records.extend(batch)
        if not data.get("pagination", {}).get("has_more"):
            break
        page += 1

    for t in records:
        upsert(conn, "sportmonks__types", t["id"], t, "sportmonks/core/types")

    log.info("Types: %d upserted", len(records))
