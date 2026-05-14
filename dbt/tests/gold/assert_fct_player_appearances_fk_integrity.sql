-- For real appearances (not sentinel rows), player_sk, team_sk, and match_sk
-- must resolve to real dimension rows (not Unknown/-1).
-- Warn only: ~4500 lineup rows reference historical players not fetched by /players endpoint.
{{ config(severity='warn') }}
SELECT 'player_sk' AS fk, match_sk, player_sk FROM {{ ref('fct_player_appearances') }}
WHERE match_sk > 0 AND player_sk = -1
UNION ALL
SELECT 'team_sk',   match_sk, player_sk FROM {{ ref('fct_player_appearances') }}
WHERE match_sk > 0 AND team_sk = -1
UNION ALL
SELECT 'match_sk',  match_sk, player_sk FROM {{ ref('fct_player_appearances') }}
WHERE player_sk > 0 AND match_sk = -1
