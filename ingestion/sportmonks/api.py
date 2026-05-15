"""
Sportmonks API client.
All modules call get() or get_paginated() — nothing else touches requests directly.
"""

import logging
import os
import time

import requests

from config import API_BASE, API_CALL_DELAY, MAX_RETRIES, PER_PAGE, REQUEST_TIMEOUT  # noqa: F401

log = logging.getLogger(__name__)

_API_KEY: str | None = None


def _headers() -> dict:
    global _API_KEY
    if _API_KEY is None:
        _API_KEY = os.environ["SPORTMONKS_API_KEY"]
    return {"Authorization": _API_KEY}


def get(path: str, params: dict = None, base: str = API_BASE) -> dict:
    url = f"{base}{path}"
    params = params or {}
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, headers=_headers(), params=params, timeout=REQUEST_TIMEOUT)
        except requests.RequestException as exc:
            log.warning("Request error (attempt %d/%d): %s", attempt + 1, MAX_RETRIES, exc)
            time.sleep(min(5 * 2 ** attempt, 120))
            continue
        if r.status_code == 429:
            # Use retry_after from the API response if present; otherwise fall back
            # to exponential backoff capped at 600 s
            try:
                body = r.json()
                retry_after = (
                    body.get("retry_after")
                    or body.get("message", {}).get("retry_after")
                    or 0
                )
                entity = body.get("requested_entity", "unknown")
            except (ValueError, AttributeError, KeyError):
                retry_after, entity = 0, "unknown"
            wait = int(retry_after) if retry_after else min(60 * (attempt + 1), 600)
            log.warning(
                "Rate limited (entity=%s) — sleeping %ds (attempt %d/%d)",
                entity, wait, attempt + 1, MAX_RETRIES,
            )
            time.sleep(wait)
            continue
        r.raise_for_status()
        time.sleep(API_CALL_DELAY)  # throttle: keep well below rate-limit ceiling
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
