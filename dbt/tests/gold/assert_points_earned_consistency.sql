-- Business rule: points_earned must match the goal comparison.
-- Win (goals_scored > goals_conceded)  → 3 pts
-- Draw (goals_scored = goals_conceded) → 1 pt
-- Loss (goals_scored < goals_conceded) → 0 pts
-- Any row returned here means the fact table has a corrupted points value.
SELECT
    match_sk,
    team_side_sk,
    goals_scored,
    goals_conceded,
    points_earned
FROM {{ ref('fct_match_results') }}
WHERE points_earned IS NOT NULL
  AND NOT (
      (goals_scored > goals_conceded  AND points_earned = 3) OR
      (goals_scored = goals_conceded  AND points_earned = 1) OR
      (goals_scored < goals_conceded  AND points_earned = 0)
  )
