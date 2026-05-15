{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='fixture_id'
    )
}}

WITH src AS (
    SELECT
        p.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ      AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER              AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER          AS season,
        (elem->>'$.predictions.winner.id')::INTEGER        AS predicted_winner_id,
        elem->>'$.predictions.winner.name'                 AS predicted_winner_name,
        elem->>'$.predictions.winner.comment'              AS predicted_winner_comment,
        (elem->>'$.predictions.win_or_draw')::BOOLEAN      AS win_or_draw,
        elem->>'$.predictions.under_over'                  AS under_over,
        elem->>'$.predictions.goals.home'                  AS predicted_goals_home,
        elem->>'$.predictions.goals.away'                  AS predicted_goals_away,
        elem->>'$.predictions.advice'                      AS advice,
        elem->>'$.predictions.percent.home'                AS pct_home,
        elem->>'$.predictions.percent.draw'                AS pct_draw,
        elem->>'$.predictions.percent.away'                AS pct_away,
        (elem->'$.comparison')                             AS comparison,
        (elem->'$.h2h')                                    AS h2h,
        p.ingested_at
    FROM {{ source('bronze', 'api_football__fixture_predictions') }} p
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id),
    UNNEST(p.raw_json::JSON[]) AS t(elem)
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
