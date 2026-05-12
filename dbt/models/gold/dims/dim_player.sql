WITH latest AS (
    SELECT DISTINCT ON (player_id)
        player_id,
        player_common_name,
        player_display_name,
        player_firstname,
        player_lastname,
        player_date_of_birth,
        player_height,
        player_weight,
        player_image_path,
        position_name AS player_position
    FROM {{ ref('squads') }}
    ORDER BY player_id, season_id DESC
)
SELECT
    ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
    player_id,
    player_common_name,
    player_display_name,
    player_firstname,
    player_lastname,
    player_date_of_birth,
    player_height,
    player_weight,
    player_image_path,
    player_position
FROM latest
WHERE player_id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Player',        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Player', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
