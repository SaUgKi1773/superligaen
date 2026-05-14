{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='match_id',
        merge_update_columns=['match_round_type', 'match_round_number', 'match_type', 'match_name', 'match_short_name', 'match_result', 'kick_off_time', 'match_status'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, NULL::VARCHAR, NULL::INTEGER, NULL::VARCHAR, 'Unknown Match', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, NULL::VARCHAR, NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Match', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(match_sk, match_id, match_round_type, match_round_number, match_type, match_name, match_short_name, match_result, kick_off_time, match_status) WHERE t.match_sk NOT IN (SELECT match_sk FROM {{ this }})"
        ]
    )
}}

WITH regular_season_max AS (
    SELECT
        f.season_id,
        MAX(TRY_CAST(f.round_name AS INTEGER)) AS max_round
    FROM {{ ref('fixtures') }} f
    JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    WHERE sg.name = 'Regular Season'
      AND TRY_CAST(f.round_name AS INTEGER) IS NOT NULL
    GROUP BY f.season_id
),
participants_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN location = 'home' THEN team_name       END) AS home_team_name,
        MAX(CASE WHEN location = 'home' THEN team_short_code END) AS home_team_code,
        MAX(CASE WHEN location = 'away' THEN team_name       END) AS away_team_name,
        MAX(CASE WHEN location = 'away' THEN team_short_code END) AS away_team_code
    FROM {{ ref('fixture_participants') }}
    GROUP BY fixture_id
),
scores_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'home' THEN goals END) AS goals_home,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'away' THEN goals END) AS goals_away
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id
),
src AS (
    SELECT
        f.id                                                                     AS match_id,
        sg.name                                                                  AS match_round_type,
        CASE
            WHEN sg.name != 'Regular Season'
                 AND TRY_CAST(f.round_name AS INTEGER) IS NOT NULL
                 AND TRY_CAST(f.round_name AS INTEGER) <= rsm.max_round
            THEN TRY_CAST(f.round_name AS INTEGER) + rsm.max_round
            ELSE TRY_CAST(f.round_name AS INTEGER)
        END                                                                      AS match_round_number,
        CASE sg.type_developer_name
            WHEN 'GROUP_STAGE' THEN 'Group Stage'
            WHEN 'KNOCK_OUT'   THEN 'Knockout'
        END                                                                      AS match_type,
        COALESCE(pp.home_team_name, '') || ' - ' || COALESCE(pp.away_team_name, '') AS match_name,
        COALESCE(pp.home_team_code, pp.home_team_name, '')
            || ' - ' || COALESCE(pp.away_team_code, pp.away_team_name, '')      AS match_short_name,
        CASE WHEN f.state_developer_name IN ('FT', 'FT_PEN', 'AET')
             THEN sp.goals_home::VARCHAR || ' - ' || sp.goals_away::VARCHAR
        END                                                                      AS match_result,
        lpad(EXTRACT(hour   FROM f.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::VARCHAR, 2, '0')
            || ':'
            || lpad(EXTRACT(minute FROM f.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::VARCHAR, 2, '0')
                                                                                 AS kick_off_time,
        f.state_name                                                             AS match_status
    FROM {{ ref('fixtures') }} f
    LEFT JOIN {{ ref('stages') }}      sg  ON sg.id          = f.stage_id
    LEFT JOIN regular_season_max       rsm ON rsm.season_id  = f.season_id
    LEFT JOIN participants_pivot       pp  ON pp.fixture_id  = f.id
    LEFT JOIN scores_pivot             sp  ON sp.fixture_id  = f.id
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(match_sk), 0) FROM {{ this }} WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY match_id) AS match_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY match_id) AS match_sk,
    {% endif %}
    match_id,
    match_round_type,
    match_round_number,
    match_type,
    match_name,
    match_short_name,
    match_result,
    kick_off_time,
    match_status
FROM src
