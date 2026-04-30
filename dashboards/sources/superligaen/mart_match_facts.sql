SELECT
    d.date                                                                   AS match_date,
    m.season,
    m.match_round_name,
    m.match_round_type,
    m.match_round_number,
    m.match_id,
    m.match_name,
    m.match_short_name,
    m.match_result                                                           AS score,
    m.match_status,
    m.kick_off_time,
    t.team_name,
    f.team_sk,
    ot.opponent_team_name,
    f.opponent_team_sk,
    ts.team_side,
    r.match_result                                                           AS result,
    ref.referee_name,
    st.stadium_name,
    f.points_earned,
    f.goals_scored,
    f.goals_conceded,
    f.goals_ht_scored,
    f.goals_ht_conceded,
    f.shots_on_goal,
    f.shots_off_goal,
    f.total_shots,
    f.blocked_shots,
    f.shots_insidebox,
    f.shots_outsidebox,
    f.ball_possession_pct                                                    AS possession_pct,
    f.total_passes,
    f.passes_accurate,
    ROUND(f.passes_accurate::DOUBLE / NULLIF(f.total_passes, 0) * 100, 1)   AS pass_accuracy,
    f.fouls,
    f.corner_kicks,
    f.offsides,
    f.yellow_cards,
    f.red_cards,
    f.goalkeeper_saves                                                       AS saves,
    ROUND(f.expected_goals::DOUBLE, 2)                                       AS xg,
    CASE
        WHEN MAX(CASE WHEN m.match_round_type = 'Championship Group' THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, m.season) = 1
            THEN 'Championship Group'
        WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Group'   THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, m.season) = 1
            THEN 'Relegation Group'
        ELSE 'Regular Season'
    END                                                                      AS standings_type,
    SUM(f.points_earned) OVER (
        PARTITION BY f.team_sk, m.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_points,
    SUM(f.goals_scored - f.goals_conceded) OVER (
        PARTITION BY f.team_sk, m.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gd,
    SUM(f.goals_scored) OVER (
        PARTITION BY f.team_sk, m.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gf
FROM superligaen.gold.fct_match_results  f
JOIN superligaen.gold.dim_date           d   ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_match          m   ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team           t   ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team  ot  ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk   = f.match_result_sk
JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk      = f.referee_sk
JOIN superligaen.gold.dim_stadium        st  ON st.stadium_sk       = f.stadium_sk
WHERE f.match_result_sk > 0
