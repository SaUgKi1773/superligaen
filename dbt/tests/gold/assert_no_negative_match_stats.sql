-- All match-level counting stats must be non-negative.
SELECT 'goals_scored'    AS col, match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE goals_scored    < 0
UNION ALL
SELECT 'goals_conceded',           match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE goals_conceded  < 0
UNION ALL
SELECT 'goals_ht_scored',          match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE goals_ht_scored < 0
UNION ALL
SELECT 'goals_ht_conceded',        match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE goals_ht_conceded < 0
UNION ALL
SELECT 'corner_kicks',             match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE corner_kicks    < 0
UNION ALL
SELECT 'yellow_cards',             match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE yellow_cards    < 0
UNION ALL
SELECT 'red_cards',                match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE red_cards       < 0
UNION ALL
SELECT 'ball_possession_pct',      match_sk, team_sk FROM {{ ref('fct_team_matches') }} WHERE ball_possession_pct < 0
