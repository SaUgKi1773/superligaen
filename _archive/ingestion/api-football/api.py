"""
API client for api-football.com v3.

Handles authentication, rate limiting, and retries with exponential backoff.
All other modules call api_get() — nothing else touches requests directly.
"""

import logging
import os
import time

import requests

from config import API_BASE, MAX_RETRIES

log = logging.getLogger(__name__)


def _headers() -> dict:
    return {"x-apisports-key": os.environ["API_FOOTBALL_KEY"]}


def api_get(endpoint: str, params: dict) -> dict:
    url = f"{API_BASE}/{endpoint}"
    for attempt in range(MAX_RETRIES):
        resp = requests.get(url, headers=_headers(), params=params, timeout=30)

        if resp.status_code == 429:
            wait = 60 * (attempt + 1)
            log.warning("Rate limit (HTTP 429) — waiting %ds before retry %d/%d", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        resp.raise_for_status()
        data = resp.json()

        if data.get("errors") and "rateLimit" in str(data["errors"]):
            wait = 60 * (attempt + 1)
            log.warning("Rate limit (API error) — waiting %ds before retry %d/%d", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        if data.get("errors"):
            raise RuntimeError(f"API error on {endpoint}: {data['errors']}")

        remaining = resp.headers.get("x-ratelimit-requests-remaining")
        if remaining is not None:
            log.info("API requests remaining today: %s", remaining)

        return data

    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {endpoint} {params}")
