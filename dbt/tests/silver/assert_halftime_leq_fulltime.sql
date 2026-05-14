{{ config(severity='warn') }}
-- Halftime goals can never exceed fulltime goals.
-- Rewritten to use fixture_scores since the new silver model stores scores separately.
-- Severity warn: a handful of fixtures have known Sportmonks score corruption where
-- CURRENT does not equal 1ST_HALF + 2ND_HALF.
WITH scores AS (
    SELECT
        fixture_id,
        side,
        MAX(CASE WHEN description = 'CURRENT'  THEN goals END) AS goals_ft,
        MAX(CASE WHEN description = '1ST_HALF' THEN goals END) AS goals_ht
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, side
)
SELECT s.fixture_id, s.side, s.goals_ht, s.goals_ft
FROM scores s
JOIN {{ ref('fixtures') }} f ON f.id = s.fixture_id
WHERE f.state_developer_name IN ('FT', 'FT_PEN', 'AET')
  AND s.goals_ht IS NOT NULL
  AND s.goals_ft IS NOT NULL
  AND s.goals_ht > s.goals_ft
