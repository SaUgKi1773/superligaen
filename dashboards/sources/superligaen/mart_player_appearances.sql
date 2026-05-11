SELECT
    d.season,
    d.date                              AS match_date,
    m.match_round_number,
    m.match_round_name,
    m.match_id,
    p.player_id,
    p.player_name,
    p.player_position,
    p.player_nationality,
    t.team_name,
    COALESCE(opp.team_name, 'Unknown')  AS opponent_team_name,
    r.match_result                      AS result,
    a.appearance_type,
    f.minutes_played,
    f.goals_scored,
    f.assists,
    f.goals_conceded,
    f.saves,
    f.total_shots,
    f.shots_on_goal,
    f.total_passes,
    f.passes_accurate,
    f.passes_key,
    f.tackles_total,
    f.interceptions,
    f.duels_total,
    f.duels_won,
    f.dribbles_attempts,
    f.dribbles_success,
    f.fouls_committed,
    f.fouls_drawn,
    f.yellow_cards,
    f.red_cards,
    f.offsides,
    f.rating
FROM superligaen.gold.fct_player_appearances     f
JOIN superligaen.gold.dim_date                   d   ON d.date_sk              = f.date_sk
JOIN superligaen.gold.dim_match                  m   ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_player                 p   ON p.player_sk            = f.player_sk
JOIN superligaen.gold.dim_team                   t   ON t.team_sk              = f.team_sk
LEFT JOIN superligaen.gold.dim_team              opp ON opp.team_sk            = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result           r   ON r.match_result_sk      = f.match_result_sk
JOIN superligaen.gold.dim_appearance_type        a   ON a.appearance_type_sk   = f.appearance_type_sk
WHERE f.player_sk > 0
  AND f.match_result_sk IN (1, 2, 3)
