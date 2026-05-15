-- Every match in dim_match with a known result must have rows in fct_team_matches.
-- A missing match means a broken incremental load silently dropped finished data.
SELECT dm.match_sk, dm.match_name
FROM {{ ref('dim_match') }} dm
WHERE dm.match_sk > 0
  AND dm.match_status IN ('Full Time', 'After Extra Time', 'After Penalties')
  AND dm.match_sk NOT IN (SELECT DISTINCT match_sk FROM {{ ref('fct_team_matches') }} WHERE match_sk > 0)
