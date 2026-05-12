"""
Sportmonks API client.
All modules call get() or get_paginated() — nothing else touches requests directly.
"""

import logging
import os
import time

import requests

from config import API_BASE, MAX_RETRIES, PER_PAGE

log = logging.getLogger(__name__)


def _headers() -> dict:
    return {"Authorization": os.environ["SPORTMONKS_API_KEY"]}


def get(path: str, params: dict | None = None) -> dict:
    url = f"{API_BASE}{path}"
    params = params or {}
    for attempt in range(MAX_RETRIES):
        r = requests.get(url, headers=_headers(), params=params, timeout=60)
        if r.status_code == 429:
            wait = 60 * (attempt + 1)
            log.warning("Rate limited — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue
        r.raise_for_status()
        return r.json()
    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {path} {params}")


def get_paginated(path: str, params: dict | None = None) -> list:
    """Fetch all pages and return a flat list of records."""
    params = {**(params or {}), "per_page": PER_PAGE, "page": 1}
    results = []
    while True:
        data = get(path, params)
        batch = data.get("data", [])
        results.extend(batch if isinstance(batch, list) else [batch])
        if not data.get("pagination", {}).get("has_more"):
            break
        params["page"] += 1
    log.debug("%s — fetched %d total records", path, len(results))
    return results
