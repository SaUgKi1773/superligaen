"""
Sportmonks API v3 client.

All HTTP calls go through api_get(). Handles authentication, pagination,
rate-limit back-off, and retries with exponential back-off.
"""

import logging
import os
import time
from typing import Iterator

import requests

from config import API_BASE, MAX_RETRIES

log = logging.getLogger(__name__)

_session: requests.Session | None = None


def _get_session() -> requests.Session:
    global _session
    if _session is None:
        _session = requests.Session()
    return _session


def _token() -> str:
    token = os.environ.get("SPORTMONKS_KEY")
    if not token:
        raise RuntimeError("SPORTMONKS_KEY env var is not set")
    return token


def api_get(endpoint: str, params: dict | None = None) -> dict:
    """Fetch a single page from the API. Returns the full response dict."""
    url = f"{API_BASE}/{endpoint}"
    p = dict(params or {})
    p["api_token"] = _token()

    for attempt in range(MAX_RETRIES):
        resp = _get_session().get(url, params=p, timeout=30)

        if resp.status_code == 429:
            wait = _rate_limit_wait(resp, attempt)
            log.warning("Rate limited (HTTP 429) — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        resp.raise_for_status()
        data = resp.json()

        if "rate limit" in str(data.get("message", "")).lower() or data.get("rate_limit", {}).get("remaining", 999) == 0:
            wait = _rate_limit_wait(resp, attempt)
            log.warning("Rate limit — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        rl = data.get("rate_limit", {})
        if rl:
            log.debug(
                "Rate limit: %d remaining, resets in %ds [entity: %s]",
                rl.get("remaining", -1),
                rl.get("resets_in_seconds", -1),
                rl.get("requested_entity", "?"),
            )

        return data

    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {endpoint}")


def _rate_limit_wait(resp: requests.Response, attempt: int) -> int:
    """Return seconds to wait on a rate-limit response.

    Reads resets_in_seconds from the JSON body when available (only present
    on successful responses, not on rate-limit error bodies). Falls back to
    a fixed 10-minute wait, which is conservative but avoids stalling a run
    for the full hour in most cases.
    """
    try:
        resets_in = resp.json().get("rate_limit", {}).get("resets_in_seconds")
        if resets_in and resets_in > 0:
            return int(resets_in) + 5  # small buffer
    except Exception:
        pass
    return 600  # 10 min default when reset time is unknown


def api_get_all(endpoint: str, params: dict | None = None) -> Iterator[dict]:
    """Paginate through all pages and yield each response dict.

    Always passes the original params (filters, includes) on every page request
    so that filters and includes are not silently dropped on pages 2+.
    """
    p = dict(params or {})
    page = 1

    while True:
        p["page"] = page
        resp = api_get(endpoint, p)

        pagination = resp.get("pagination", {})
        total_pages = (
            -(-pagination["count"] // pagination["per_page"])  # ceiling division
            if pagination.get("count") and pagination.get("per_page")
            else "?"
        )
        log.info("  %s — page %d/%s (%d records)", endpoint, page, total_pages, len(resp.get("data", [])))

        yield resp

        if not pagination.get("has_more"):
            break
        page += 1
