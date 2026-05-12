-- Home + away possession must sum to 100% per match (within 1pp rounding tolerance).
-- A violation means the API returned corrupted possession data for that match.
SELECT
    match_sk,
    sum(ball_possession_pct) AS total_possession
FROM {{ ref('fct_match_results') }}
WHERE ball_possession_pct IS NOT NULL
  AND match_sk > 0
GROUP BY match_sk
HAVING abs(sum(ball_possession_pct) - 100) > 1
