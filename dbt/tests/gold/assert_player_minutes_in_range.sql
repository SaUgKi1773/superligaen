-- Player minutes must be between 0 and 120 (90 min + 30 min extra time).
-- Values outside this range indicate a data pipeline error.
SELECT match_sk, player_sk, minutes_played
FROM {{ ref('fct_player_appearances') }}
WHERE minutes_played < 0 OR minutes_played > 120
