{{
    config(materialized='view')
}}

SELECT
    team_sk           AS opponent_team_sk,
    team_id           AS opponent_team_id,
    team_name         AS opponent_team_name,
    team_short_code   AS opponent_team_short_code,
    team_founded_year AS opponent_team_founded_year,
    team_image_path   AS opponent_team_image_path
FROM {{ ref('dim_team') }}
