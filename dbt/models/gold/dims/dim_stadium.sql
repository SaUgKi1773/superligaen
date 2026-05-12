WITH from_venues AS (
    SELECT id AS venue_id, name, city_name AS city, address, surface, capacity
    FROM {{ ref('venues') }}
    WHERE id IS NOT NULL
),
from_fixtures AS (
    SELECT DISTINCT
        venue_id,
        venue_name   AS name,
        venue_city   AS city,
        NULL         AS address,
        venue_surface AS surface,
        venue_capacity AS capacity
    FROM {{ ref('fixtures') }}
    WHERE venue_id IS NOT NULL
      AND venue_id NOT IN (SELECT venue_id FROM from_venues)
      AND venue_name IS NOT NULL
),
combined AS (
    SELECT * FROM from_venues
    UNION ALL
    SELECT * FROM from_fixtures
)
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    venue_id    AS stadium_id,
    name        AS stadium_name,
    city        AS stadium_city,
    address     AS stadium_address,
    surface     AS stadium_surface,
    capacity    AS stadium_capacity
FROM combined
UNION ALL SELECT -1, NULL, 'Unknown Stadium',        NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Stadium', NULL, NULL, NULL, NULL
