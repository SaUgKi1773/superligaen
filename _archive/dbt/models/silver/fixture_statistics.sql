{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['fixture_id', 'team_id']
    )
}}

WITH src AS (
    SELECT
        s.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ  AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER          AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER      AS season,
        (te->>'$.team.id')::INTEGER                    AS team_id,
        te->>'$.team.name'                             AS team_name,
        te->>'$.team.logo'                             AS team_logo,
        MAX(CASE WHEN stat->>'$.type' = 'Shots on Goal'     THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS shots_on_goal,
        MAX(CASE WHEN stat->>'$.type' = 'Shots off Goal'    THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS shots_off_goal,
        MAX(CASE WHEN stat->>'$.type' = 'Total Shots'       THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS total_shots,
        MAX(CASE WHEN stat->>'$.type' = 'Blocked Shots'     THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS blocked_shots,
        MAX(CASE WHEN stat->>'$.type' = 'Shots insidebox'   THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS shots_insidebox,
        MAX(CASE WHEN stat->>'$.type' = 'Shots outsidebox'  THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS shots_outsidebox,
        MAX(CASE WHEN stat->>'$.type' = 'Fouls'             THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS fouls,
        MAX(CASE WHEN stat->>'$.type' = 'Corner Kicks'      THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS corner_kicks,
        COALESCE(MAX(CASE WHEN stat->>'$.type' = 'Offsides'          THEN TRY_CAST(stat->>'$.value' AS INTEGER) END), 0) AS offsides,
        MAX(CASE WHEN stat->>'$.type' = 'Ball Possession'   THEN TRY_CAST(REPLACE(stat->>'$.value', '%', '') AS DECIMAL(5,2)) END) AS ball_possession_pct,
        COALESCE(MAX(CASE WHEN stat->>'$.type' = 'Yellow Cards' THEN TRY_CAST(stat->>'$.value' AS INTEGER)                     END), 0) AS yellow_cards,
        COALESCE(MAX(CASE WHEN stat->>'$.type' = 'Red Cards' THEN TRY_CAST(stat->>'$.value' AS INTEGER)                       END), 0) AS red_cards,
        COALESCE(MAX(CASE WHEN stat->>'$.type' = 'Goalkeeper Saves'  THEN TRY_CAST(stat->>'$.value' AS INTEGER) END), 0) AS goalkeeper_saves,
        MAX(CASE WHEN stat->>'$.type' = 'Total passes'      THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS total_passes,
        MAX(CASE WHEN stat->>'$.type' = 'Passes accurate'   THEN TRY_CAST(stat->>'$.value' AS INTEGER)                        END) AS passes_accurate,
        MAX(CASE WHEN stat->>'$.type' = 'Passes %'          THEN TRY_CAST(REPLACE(stat->>'$.value', '%', '') AS DECIMAL(5,2)) END) AS passes_pct,
        MAX(CASE WHEN stat->>'$.type' = 'expected_goals'    THEN TRY_CAST(stat->>'$.value' AS DECIMAL(6,3))                   END) AS expected_goals,
        s.ingested_at
    FROM {{ source('bronze', 'api_football__fixture_statistics') }} s
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id),
    UNNEST(s.raw_json::JSON[]) AS t1(te),
    UNNEST((te->'$.statistics')::JSON[]) AS t2(stat)
    GROUP BY s.fixture_id, kick_off, league_id, season, team_id, team_name, team_logo, s.ingested_at
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
