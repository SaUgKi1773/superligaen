{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='fixture_id'
    )
}}

WITH src AS (
    SELECT
        o.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ  AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER          AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER      AS season,
        (bm->>'$.id')::INTEGER                         AS bookmaker_id,
        bm->>'$.name'                                  AS bookmaker_name,
        (bet->>'$.id')::INTEGER                        AS bet_id,
        bet->>'$.name'                                 AS bet_name,
        val->>'$.value'                                AS bet_value,
        val->>'$.odd'                                  AS odd,
        o.ingested_at
    FROM {{ source('bronze', 'api_football__fixture_odds') }} o
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id),
    UNNEST(o.raw_json::JSON[]) AS t1(wrap),
    UNNEST((wrap->'$.bookmakers')::JSON[]) AS t2(bm),
    UNNEST((bm->'$.bets')::JSON[]) AS t3(bet),
    UNNEST((bet->'$.values')::JSON[]) AS t4(val)
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
