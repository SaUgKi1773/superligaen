{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='player_id',
        merge_update_columns=['player_name', 'firstname', 'lastname', 'nationality', 'birth_date', 'birth_place', 'birth_country', 'height', 'weight', 'photo', 'position', 'current_shirt_number', 'current_team_id', 'current_team_name'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player Name', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Player Name', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR)) t(player_sk, player_id, player_name, firstname, lastname, nationality, birth_date, birth_place, birth_country, height, weight, photo, position, current_shirt_number, current_team_id, current_team_name) WHERE t.player_sk NOT IN (SELECT player_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (player_id)
        player_id,
        player_name,
        firstname,
        lastname,
        nationality,
        birth_date,
        birth_place,
        birth_country,
        height,
        weight,
        photo,
        position,
        shirt_number AS current_shirt_number,
        team_id      AS current_team_id,
        team_name    AS current_team_name
    FROM {{ ref('players') }}
    {% if is_incremental() %}
    WHERE {{ season_filter() }}
    {% endif %}
    ORDER BY player_id, season DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(player_sk), 0) FROM {{ this }} WHERE player_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.player_id) AS player_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.player_id) AS player_sk,
    {% endif %}
    src.player_id,
    src.player_name,
    src.firstname,
    src.lastname,
    src.nationality,
    src.birth_date,
    src.birth_place,
    src.birth_country,
    src.height,
    src.weight,
    src.photo,
    src.position,
    src.current_shirt_number,
    src.current_team_id,
    src.current_team_name
FROM latest src
WHERE src.player_id IS NOT NULL
