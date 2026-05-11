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
            wait = 60 * (attempt + 1)
            log.warning("Rate limited — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        resp.raise_for_status()
        data = resp.json()

        if "message" in data and "rate" in str(data.get("message", "")).lower():
            wait = 60 * (attempt + 1)
            log.warning("Rate limit in body — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
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


def api_get_all(endpoint: str, params: dict | None = None) -> Iterator[dict]:
    """Paginate through all pages and yield each response dict."""
    p = dict(params or {})
    url: str | None = f"{API_BASE}/{endpoint}"

    while url:
        # After the first page, Sportmonks returns full next_page URLs
        if url.startswith("http"):
            # Strip the base and api_token from the next_page URL — api_get re-adds token
            resp = api_get_full_url(url, params={"api_token": _token()})
        else:
            resp = api_get(url, params=p)

        yield resp

        pagination = resp.get("pagination", {})
        url = pagination.get("next_page") if pagination.get("has_more") else None


def api_get_full_url(url: str, params: dict | None = None) -> dict:
    """Fetch an absolute URL (used for paginated next_page links)."""
    p = dict(params or {})
    p.setdefault("api_token", _token())

    for attempt in range(MAX_RETRIES):
        resp = _get_session().get(url, params=p, timeout=30)

        if resp.status_code == 429:
            wait = 60 * (attempt + 1)
            log.warning("Rate limited — waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        resp.raise_for_status()
        return resp.json()

    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {url}")
