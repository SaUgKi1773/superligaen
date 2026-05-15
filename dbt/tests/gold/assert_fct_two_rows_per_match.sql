-- Every completed match must have exactly 2 rows in fct_team_matches: home + away.
-- Violations indicate a broken incremental merge or missing participant data.
SELECT match_sk, count(*) AS row_count
FROM {{ ref('fct_team_matches') }}
WHERE match_sk > 0
GROUP BY match_sk
HAVING count(*) != 2
