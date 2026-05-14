-- Halftime goals scored/conceded can never exceed fulltime totals.
-- Warn only: 3 Sportmonks fixtures have known corrupted score data (same as silver halftime test).
{{ config(severity='warn') }}
SELECT match_sk, team_sk, goals_ht_scored, goals_scored, goals_ht_conceded, goals_conceded
FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3)
  AND (
      (goals_ht_scored   IS NOT NULL AND goals_ht_scored   > goals_scored)
   OR (goals_ht_conceded IS NOT NULL AND goals_ht_conceded > goals_conceded)
  )
