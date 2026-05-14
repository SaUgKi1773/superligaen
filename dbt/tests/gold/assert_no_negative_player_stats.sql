-- All player counting stats must be non-negative. Negative values indicate
-- a corrupted type_id pivot or bad API data.
SELECT match_sk, player_sk, col
FROM {{ ref('fct_player_appearances') }}
UNPIVOT (val FOR col IN (
    goals_scored, own_goals, assists,
    shots_total, shots_on_target, shots_off_target, shots_blocked,
    passes_total, passes_accurate, key_passes,
    tackles, clearances, interceptions, aerials_won, aerials_lost, blocks,
    duels_total, duels_won, dribbles_attempts, dribbles_completed,
    fouls_committed, fouls_drawn, yellow_cards, red_cards, offsides,
    minutes_played
))
WHERE val < 0
