WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)  AS shots_on_goal,
        SUM(shots_off_target) AS shots_off_goal,
        SUM(shots_total)      AS total_shots,
        SUM(shots_blocked)    AS blocked_shots,
        SUM(passes_total)          AS total_passes,
        SUM(passes_accurate)       AS passes_accurate,
        SUM(fouls_committed)       AS fouls,
        SUM(saves)                 AS goalkeeper_saves,
        SUM(offsides)              AS offsides,
        SUM(tackles)               AS tackles,
        SUM(key_passes)            AS key_passes,
        SUM(big_chances_created)   AS big_chances_created,
        SUM(woodwork_hits)         AS woodwork_hits,
        SUM(crosses_total)         AS crosses_total,
        SUM(crosses_accurate)      AS crosses_accurate
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
)
SELECT
    d.date                                                                   AS match_date,
    d.season,
    d.is_current_season,
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
    t.team_short_name,
    t.team_code,
    t.team_logo,
    f.team_sk,
    ot.opponent_team_name,
    ot.opponent_team_short_name,
    ot.opponent_team_code,
    f.opponent_team_sk,
    ts.team_side,
    r.match_result                                                           AS result,
    ref.referee_common_name                                                  AS referee_name,
    dc.coach_name,
    st.stadium_name,
    st.stadium_surface,
    st.stadium_capacity,
    st.stadium_latitude,
    st.stadium_longitude,
    f.points_earned,
    f.goals_scored,
    f.goals_conceded,
    f.goals_ht_scored,
    f.goals_ht_conceded,
    f.ball_possession_pct                                                    AS possession_pct,
    f.corner_kicks,
    f.yellow_cards,
    f.red_cards,
    COALESCE(pa.shots_on_goal,    0)                                        AS shots_on_goal,
    COALESCE(pa.shots_off_goal,   0)                                        AS shots_off_goal,
    COALESCE(pa.total_shots,      0)                                        AS total_shots,
    COALESCE(pa.blocked_shots,    0)                                        AS blocked_shots,
    COALESCE(pa.total_passes,     0)                                        AS total_passes,
    COALESCE(pa.passes_accurate,  0)                                        AS passes_accurate,
    COALESCE(pa.fouls,              0)                                      AS fouls,
    COALESCE(pa.goalkeeper_saves,  0)                                      AS saves,
    COALESCE(pa.offsides,          0)                                      AS offsides,
    COALESCE(pa.tackles,           0)                                      AS tackles,
    COALESCE(pa.key_passes,        0)                                      AS key_passes,
    COALESCE(pa.big_chances_created, 0)                                    AS big_chances_created,
    COALESCE(pa.woodwork_hits,     0)                                      AS woodwork_hits,
    COALESCE(pa.crosses_total,     0)                                      AS crosses_total,
    COALESCE(pa.crosses_accurate,  0)                                      AS crosses_accurate,
    CASE
        WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, d.season) = 1
            THEN 'Championship Group'
        WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, d.season) = 1
            THEN 'Relegation Group'
        ELSE 'Regular Season'
    END                                                                      AS standings_type,
    SUM(f.points_earned) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_points,
    SUM(f.goals_scored - f.goals_conceded) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gd,
    SUM(f.goals_scored) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gf
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date           d   ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_match          m   ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team           t   ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team  ot  ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk   = f.match_result_sk
JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk      = f.referee_sk
JOIN superligaen.gold.dim_stadium        st  ON st.stadium_sk       = f.stadium_sk
LEFT JOIN superligaen.gold.dim_coach     dc  ON dc.coach_sk         = f.coach_sk
LEFT JOIN player_agg                         pa  ON pa.match_sk         = f.match_sk
                                                AND pa.team_sk          = f.team_sk
WHERE f.match_result_sk > 0
  AND m.match_round_number IS NOT NULL
  AND d.season >= '2020/21'
