WITH latest AS (
    SELECT DISTINCT ON (id)
        id, name, short_code, founded, image_path
    FROM {{ ref('teams') }}
    ORDER BY id, last_played_at DESC NULLS LAST
)
SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS team_sk,
    id                              AS team_id,
    name                            AS team_name,
    short_code                      AS team_short_code,
    founded                         AS team_founded_year,
    image_path                      AS team_image_path
FROM latest
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Team',        NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Team', NULL, NULL, NULL
