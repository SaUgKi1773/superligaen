-- A team's played count must equal wins + draws + losses.
SELECT team_id, team_name, season_id, overall_played, overall_won, overall_draw, overall_lost,
       overall_won + overall_draw + overall_lost AS wdl_sum
FROM {{ ref('standings') }}
WHERE overall_played IS NOT NULL
  AND overall_won    IS NOT NULL
  AND overall_draw   IS NOT NULL
  AND overall_lost   IS NOT NULL
  AND overall_played != overall_won + overall_draw + overall_lost
