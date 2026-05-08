-- Standings consistency: a team's played count must equal wins + draws + losses.
-- Any row returned here means the API sent internally inconsistent data.
SELECT
    season,
    league_id,
    team_id,
    team_name,
    played,
    wins,
    draws,
    losses,
    wins + draws + losses AS wdl_sum
FROM {{ ref('standings') }}
WHERE played IS NOT NULL
  AND wins    IS NOT NULL
  AND draws   IS NOT NULL
  AND losses  IS NOT NULL
  AND played != wins + draws + losses
