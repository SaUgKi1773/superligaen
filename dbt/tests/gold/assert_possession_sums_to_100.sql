-- Home + away possession must sum to 100% per match (within 1pp rounding tolerance).
-- Only checked when both teams report possession (i.e. count = 2 non-NULL rows).
SELECT match_sk, sum(ball_possession_pct) AS total_possession
FROM {{ ref('fct_team_matches') }}
WHERE ball_possession_pct IS NOT NULL
  AND match_sk > 0
GROUP BY match_sk
HAVING count(*) = 2
   AND abs(sum(ball_possession_pct) - 100) > 1
