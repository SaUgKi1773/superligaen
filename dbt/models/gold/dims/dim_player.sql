WITH squad_positions AS (
    -- Most-recent position name per player from squad data
    SELECT DISTINCT ON (player_id)
        player_id,
        position_name,
        position_code
    FROM {{ ref('squads') }}
    WHERE position_name IS NOT NULL
    ORDER BY player_id, season_id DESC
),
src AS (
    SELECT
        p.id           AS player_id,
        p.common_name,
        p.display_name,
        p.firstname,
        p.lastname,
        p.date_of_birth,
        p.height,
        p.weight,
        p.image_path,
        p.country_id,
        p.nationality_id,
        c.name         AS nationality_name,
        COALESCE(sp.position_name, pt.name) AS position_name
    FROM {{ ref('core_players') }} p
    LEFT JOIN {{ ref('core_countries') }} c ON c.id = p.nationality_id
    LEFT JOIN squad_positions sp ON sp.player_id = p.id
    LEFT JOIN {{ ref('types') }} pt ON pt.id = p.position_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
    player_id,
    common_name,
    display_name,
    firstname,
    lastname,
    date_of_birth,
    EXTRACT(YEAR FROM date_of_birth)::INTEGER AS birth_year,
    height,
    weight,
    image_path,
    country_id,
    nationality_id,
    nationality_name,
    position_name
FROM src
WHERE player_id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Player',        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Player', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
