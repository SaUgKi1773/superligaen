{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='player_id',
        merge_update_columns=['player_name', 'player_firstname', 'player_lastname', 'player_nationality', 'player_birth_date', 'player_birth_place', 'player_birth_country', 'player_height', 'player_weight', 'player_photo', 'player_position', 'player_detailed_position'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::DATE, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Player', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::DATE, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(player_sk, player_id, player_name, player_firstname, player_lastname, player_nationality, player_birth_date, player_birth_place, player_birth_country, player_height, player_weight, player_photo, player_position, player_detailed_position) WHERE t.player_sk NOT IN (SELECT player_sk FROM {{ this }})"
        ]
    )
}}

WITH from_players AS (
    SELECT DISTINCT ON (id)
        id             AS player_id,
        display_name   AS player_name,
        firstname      AS player_firstname,
        lastname       AS player_lastname,
        nationality_name AS player_nationality,
        date_of_birth  AS player_birth_date,
        city_name      AS player_birth_place,
        country_name   AS player_birth_country,
        height         AS player_height,
        weight         AS player_weight,
        image_path     AS player_photo,
        position_name  AS player_position,
        detailed_position_name AS player_detailed_position
    FROM {{ ref('players') }}
    WHERE id IS NOT NULL
      AND position_name != 'Coach'
    ORDER BY id, _ingested_at DESC
),
from_lineups AS (
    SELECT DISTINCT ON (player_id)
        player_id,
        player_name,
        NULL::VARCHAR  AS player_firstname,
        NULL::VARCHAR  AS player_lastname,
        NULL::VARCHAR  AS player_nationality,
        NULL::DATE     AS player_birth_date,
        NULL::VARCHAR  AS player_birth_place,
        NULL::VARCHAR  AS player_birth_country,
        NULL::INTEGER  AS player_height,
        NULL::INTEGER  AS player_weight,
        NULL::VARCHAR  AS player_photo,
        position_name  AS player_position,
        detailed_position_name AS player_detailed_position
    FROM {{ ref('fixture_lineups') }}
    WHERE player_id IS NOT NULL
      AND player_id NOT IN (SELECT player_id FROM from_players)
    ORDER BY player_id, _ingested_at DESC
),
combined AS (
    SELECT * FROM from_players
    UNION ALL
    SELECT * FROM from_lineups
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(player_sk), 0) FROM {{ this }} WHERE player_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
    {% endif %}
    player_id,
    player_name,
    player_firstname,
    player_lastname,
    player_nationality,
    player_birth_date,
    player_birth_place,
    player_birth_country,
    player_height,
    player_weight,
    player_photo,
    player_position,
    player_detailed_position
FROM combined
