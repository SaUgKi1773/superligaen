-- Win → 3 pts, Draw → 1 pt, Loss → 0 pts. Any violation means corrupted fact data.
SELECT match_sk, team_side_sk, goals_scored, goals_conceded, points_earned
FROM {{ ref('fct_team_matches') }}
WHERE points_earned IS NOT NULL
  AND NOT (
      (goals_scored > goals_conceded AND points_earned = 3) OR
      (goals_scored = goals_conceded AND points_earned = 1) OR
      (goals_scored < goals_conceded AND points_earned = 0)
  )
