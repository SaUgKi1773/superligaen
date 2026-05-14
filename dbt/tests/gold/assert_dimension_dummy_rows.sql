-- Every dimension with FK references in the fact tables must have sentinel rows
-- -1 (Unknown) and -2 (Not Applicable). Missing sentinels mean unresolved FKs
-- silently disappear from dimension joins.
SELECT 'dim_team'        AS dim_name, expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT team_sk         FROM {{ ref('dim_team') }})
UNION ALL
SELECT 'dim_match',        expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT match_sk        FROM {{ ref('dim_match') }})
UNION ALL
SELECT 'dim_league',       expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT league_sk       FROM {{ ref('dim_league') }})
UNION ALL
SELECT 'dim_stadium',      expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT stadium_sk      FROM {{ ref('dim_stadium') }})
UNION ALL
SELECT 'dim_referee',      expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT referee_sk      FROM {{ ref('dim_referee') }})
UNION ALL
SELECT 'dim_match_result', expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT match_result_sk FROM {{ ref('dim_match_result') }})
UNION ALL
SELECT 'dim_team_side',    expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT team_side_sk    FROM {{ ref('dim_team_side') }})
UNION ALL
SELECT 'dim_player',       expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT player_sk       FROM {{ ref('dim_player') }})
UNION ALL
SELECT 'dim_coach',        expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT coach_sk        FROM {{ ref('dim_coach') }})
UNION ALL
SELECT 'dim_formation',    expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT formation_sk    FROM {{ ref('dim_formation') }})
UNION ALL
SELECT 'dim_position',     expected_sk FROM (VALUES (-1), (-2)) t(expected_sk)
WHERE expected_sk NOT IN (SELECT position_sk     FROM {{ ref('dim_position') }})
