{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='match_id',
        merge_update_columns=['match_round_name', 'match_round_type', 'match_round_number', 'match_status', 'match_name', 'match_short_name', 'match_result', 'kick_off_time'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Match Round Name', 'Unknown Match Round Type', NULL::INTEGER, 'Unknown Match Status', 'Unknown Match Name', 'Unknown Match Short Name', NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Match Round Name', 'Not Applicable Match Round Type', NULL::INTEGER, 'Not Applicable Match Status', 'Not Applicable Match Name', 'Not Applicable Match Short Name', NULL::VARCHAR, NULL::VARCHAR)) t(match_sk, match_id, match_round_name, match_round_type, match_round_number, match_status, match_name, match_short_name, match_result, kick_off_time) WHERE t.match_sk NOT IN (SELECT match_sk FROM {{ this }})"
        ]
    )
}}

WITH team_round_base AS (
    SELECT fixture_id,
           ROW_NUMBER() OVER (
               PARTITION BY season, league_id, team_id
               ORDER BY kick_off
           ) AS round_number
    FROM {{ ref('fixture_statistics') }}
),
team_round AS (
    SELECT fixture_id, MIN(round_number) AS round_number
    FROM team_round_base
    GROUP BY fixture_id
),
src AS (
    SELECT
        f.fixture_id,
        f.season::VARCHAR || '/' || RIGHT((f.season + 1)::VARCHAR, 2)        AS season,
        CASE SPLIT_PART(f.league_round, ' - ', 1)
            WHEN 'Championship Group' THEN 'Championship Group'
            WHEN 'Championship Round' THEN 'Championship Group'
            WHEN 'Relegation Group'   THEN 'Relegation Group'
            WHEN 'Relegation Round'   THEN 'Relegation Group'
            ELSE SPLIT_PART(f.league_round, ' - ', 1)
        END || ' - ' || COALESCE(tr.round_number, TRY_CAST(SPLIT_PART(f.league_round, ' - ', 2) AS INTEGER))  AS match_round_name,
        CASE SPLIT_PART(f.league_round, ' - ', 1)
            WHEN 'Championship Group' THEN 'Championship Group'
            WHEN 'Championship Round' THEN 'Championship Group'
            WHEN 'Relegation Group'   THEN 'Relegation Group'
            WHEN 'Relegation Round'   THEN 'Relegation Group'
            ELSE SPLIT_PART(f.league_round, ' - ', 1)
        END                                                                   AS match_round_type,
        COALESCE(tr.round_number, TRY_CAST(SPLIT_PART(f.league_round, ' - ', 2) AS INTEGER)) AS match_round_number,
        f.status_long                                                         AS match_status,
        f.home_team_name || ' - ' || f.away_team_name                        AS match_name,
        COALESCE(ht.team_code, f.home_team_name) || ' - ' || COALESCE(awt.team_code, f.away_team_name) AS match_short_name,
        CASE
            WHEN f.status_short IN ('FT', 'AET', 'PEN')
            THEN f.goals_home::VARCHAR || ' - ' || f.goals_away::VARCHAR
        END                                                                   AS match_result,
        strftime(timezone('Europe/Copenhagen', f.kick_off), '%H:%M')         AS kick_off_time
    FROM {{ ref('fixtures') }} f
    LEFT JOIN team_round tr ON tr.fixture_id = f.fixture_id
    LEFT JOIN (
        SELECT DISTINCT ON (team_id) team_id, team_code
        FROM {{ ref('teams') }}
        ORDER BY team_id, season DESC
    ) ht ON ht.team_id = f.home_team_id
    LEFT JOIN (
        SELECT DISTINCT ON (team_id) team_id, team_code
        FROM {{ ref('teams') }}
        ORDER BY team_id, season DESC
    ) awt ON awt.team_id = f.away_team_id
    {% if is_incremental() %}
    WHERE {{ fixture_filter('f.kick_off') }}
    {% endif %}
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(match_sk), 0) FROM {{ this }} WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.fixture_id) AS match_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.fixture_id) AS match_sk,
    {% endif %}
    src.fixture_id   AS match_id,
    src.match_round_name,
    src.match_round_type,
    src.match_round_number,
    src.match_status,
    src.match_name,
    src.match_short_name,
    src.match_result,
    src.kick_off_time
FROM src
