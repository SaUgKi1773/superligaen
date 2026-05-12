-- Every dimension must have sentinel rows -1 (Unknown) and -2 (Not Applicable).
-- The fact table uses COALESCE(..., -1) so a missing sentinel row means
-- unresolved FKs silently disappear from dimension joins.
-- Any row returned here means a post_hook failed to insert a sentinel.
SELECT 'dim_team'         AS dim_name, expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT team_sk      FROM {{ ref('dim_team') }})

UNION ALL

SELECT 'dim_match',         expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT match_sk     FROM {{ ref('dim_match') }})

UNION ALL

SELECT 'dim_league',        expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT league_sk    FROM {{ ref('dim_league') }})

UNION ALL

SELECT 'dim_stadium',       expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT stadium_sk   FROM {{ ref('dim_stadium') }})

UNION ALL

SELECT 'dim_referee',       expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT referee_sk   FROM {{ ref('dim_referee') }})

UNION ALL

SELECT 'dim_match_result',  expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT match_result_sk FROM {{ ref('dim_match_result') }})

UNION ALL

SELECT 'dim_team_side',     expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT team_side_sk FROM {{ ref('dim_team_side') }})
