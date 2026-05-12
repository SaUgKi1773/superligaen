{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='team_id',
        merge_update_columns=['team_name', 'team_code', 'team_country', 'team_founded_year', 'team_logo'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Team Name', 'Unknown Team Code', 'Unknown Team Country', NULL::INTEGER, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Team Name', 'Not Applicable Team Code', 'Not Applicable Team Country', NULL::INTEGER, NULL::VARCHAR)) t(team_sk, team_id, team_name, team_code, team_country, team_founded_year, team_logo) WHERE t.team_sk NOT IN (SELECT team_sk FROM {{ this }})"
        ]
    )
}}

WITH latest_teams AS (
    SELECT DISTINCT ON (team_id)
        team_id, team_name, team_code, team_country, team_founded, team_logo
    FROM {{ ref('teams') }}
    ORDER BY team_id, season DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(team_sk), 0) FROM {{ this }} WHERE team_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.team_id) AS team_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.team_id) AS team_sk,
    {% endif %}
    src.team_id,
    src.team_name,
    src.team_code,
    src.team_country,
    src.team_founded  AS team_founded_year,
    src.team_logo
FROM latest_teams src
WHERE src.team_id IS NOT NULL
