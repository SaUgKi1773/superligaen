-- Every completed match must have exactly 2 rows in fixture_statistics (one per team).
-- Fewer means a team's stats went missing. More means a duplicate was ingested.
SELECT
    s.fixture_id,
    f.status_short,
    count(*) AS stat_rows
FROM {{ ref('fixture_statistics') }} s
JOIN {{ ref('fixtures') }} f ON f.fixture_id = s.fixture_id
WHERE f.status_short IN ('FT', 'AET', 'PEN')
GROUP BY s.fixture_id, f.status_short
HAVING count(*) != 2
