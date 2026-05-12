"""
Sportmonks API client.
All modules call get() or get_paginated() — nothing else touches requests directly.
"""

import logging
import os
import time

import requests

from config import API_BASE, CORE_API_BASE, MAX_RETRIES, PER_PAGE  # noqa: F401

log = logging.getLogger(__name__)


def _headers() -> dict:
    return {"Authorization": os.environ["SPORTMONKS_API_KEY"]}


def get(path: str, params: dict = None, base: str = API_BASE) -> dict:
    url = f"{base}{path}"
    params = params or {}
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, headers=_headers(), params=params, timeout=60)
        except requests.RequestException as exc:
            log.warning("Request error (attempt %d/%d): %s", attempt + 1, MAX_RETRIES, exc)
            time.sleep(5 * (attempt + 1))
            continue
        if r.status_code == 429:
            wait = 60 * (attempt + 1)
            log.warning("Rate limited — sleeping %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue
        r.raise_for_status()
        return r.json()
    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {url}")


def get_paginated(path: str, params: dict = None, base: str = API_BASE) -> list:
    """Fetch all pages and return a flat list of records."""
    params = {**(params or {}), "per_page": PER_PAGE, "page": 1}
    results = []
    while True:
        try:
            data = get(path, params, base)
        except requests.HTTPError as exc:
            # Sportmonks returns 400 when paging past the last page, and
            # 404 for endpoints that have no data for a given ID.
            if exc.response is not None and exc.response.status_code in (400, 404):
                break
            raise
        batch = data.get("data", [])
        if isinstance(batch, dict):
            batch = [batch]
        results.extend(batch)
        if not data.get("pagination", {}).get("has_more"):
            break
        params["page"] += 1
    log.debug("%s → %d records", path, len(results))
    return results
