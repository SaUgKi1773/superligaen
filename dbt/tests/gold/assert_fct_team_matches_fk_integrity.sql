-- For completed matches (result is Win/Draw/Loss), core dimension FKs must resolve
-- to real rows (not Unknown/-1). team_sk, opponent_team_sk, match_sk, and
-- stadium_sk falling back to -1 indicates a broken join that would corrupt reporting.
SELECT 'team_sk'          AS fk, match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND team_sk = -1
UNION ALL
SELECT 'opponent_team_sk', match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND opponent_team_sk = -1
UNION ALL
SELECT 'match_sk',         match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND match_sk = -1
UNION ALL
SELECT 'stadium_sk',       match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND stadium_sk = -1
