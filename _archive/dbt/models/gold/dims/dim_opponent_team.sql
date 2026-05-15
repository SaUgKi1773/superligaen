{{
    config(
        materialized='view',
        schema='gold'
    )
}}

SELECT
    team_sk           AS opponent_team_sk,
    team_id           AS opponent_team_id,
    team_name         AS opponent_team_name,
    team_code         AS opponent_team_code,
    team_country      AS opponent_team_country,
    team_founded_year AS opponent_team_founded_year,
    team_logo         AS opponent_team_logo
FROM {{ ref('dim_team') }}
