{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='player_id',
        merge_update_columns=['player_name', 'player_firstname', 'player_lastname', 'player_nationality', 'player_birth_date', 'player_birth_place', 'player_birth_country', 'player_height', 'player_weight', 'player_photo', 'player_position', 'player_team_name'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player Name', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Player Name', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(player_sk, player_id, player_name, player_firstname, player_lastname, player_nationality, player_birth_date, player_birth_place, player_birth_country, player_height, player_weight, player_photo, player_position, player_team_name) WHERE t.player_sk NOT IN (SELECT player_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (player_id)
        player_id,
        player_name,
        firstname     AS player_firstname,
        lastname      AS player_lastname,
        nationality   AS player_nationality,
        birth_date    AS player_birth_date,
        birth_place   AS player_birth_place,
        birth_country AS player_birth_country,
        TRY_CAST(SPLIT_PART(height, ' ', 1) AS INTEGER) AS player_height,
        TRY_CAST(SPLIT_PART(weight, ' ', 1) AS INTEGER) AS player_weight,
        photo         AS player_photo,
        position      AS player_position,
        team_name     AS player_team_name
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
    src.player_firstname,
    src.player_lastname,
    src.player_nationality,
    src.player_birth_date,
    src.player_birth_place,
    src.player_birth_country,
    src.player_height,
    src.player_weight,
    src.player_photo,
    src.player_position,
    src.player_team_name
FROM latest src
WHERE src.player_id IS NOT NULL
