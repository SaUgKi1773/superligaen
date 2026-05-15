-- Volume floor check: a bad full-refresh or wipe would produce absurdly low counts.
-- Thresholds are well below current actuals so legitimate data never fails this test.
SELECT 'dim_team'              AS model, count(*) AS actual,  10 AS min_expected FROM {{ ref('dim_team') }}     WHERE team_sk > 0 HAVING count(*) < 10
UNION ALL
SELECT 'dim_match',                      count(*),           1000               FROM {{ ref('dim_match') }}    WHERE match_sk > 0 HAVING count(*) < 1000
UNION ALL
SELECT 'dim_player',                     count(*),           500                FROM {{ ref('dim_player') }}   WHERE player_sk > 0 HAVING count(*) < 500
UNION ALL
SELECT 'fct_team_matches',               count(*),           2000               FROM {{ ref('fct_team_matches') }} WHERE match_sk > 0 HAVING count(*) < 2000
UNION ALL
SELECT 'fct_player_appearances',         count(*),           20000              FROM {{ ref('fct_player_appearances') }} WHERE match_sk > 0 HAVING count(*) < 20000
