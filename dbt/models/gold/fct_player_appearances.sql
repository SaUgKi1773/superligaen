{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'player_sk', 'team_sk']
    )
}}

WITH finished_fixtures AS (
    SELECT
        id        AS fixture_id,
        league_id,
        venue_id,
        starting_at
    FROM {{ ref('fixtures') }}
    WHERE state_developer_name IN ('FT', 'FT_PEN', 'AET')
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
team_context AS (
    SELECT
        p.fixture_id,
        p.team_id,
        CASE p.location WHEN 'home' THEN 1 ELSE 2 END AS team_side_sk,
        opp.team_id AS opponent_team_id
    FROM participants p
    JOIN participants opp
        ON opp.fixture_id = p.fixture_id
       AND opp.location  != p.location
),
team_scores AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN description = 'CURRENT' THEN goals END) AS goals
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    SELECT fixture_id, referee_id
    FROM {{ ref('fixture_referees') }}
    WHERE type_id = 6
),
-- Goals scored against each team, with the minute they occurred
goals_against_team AS (
    SELECT
        fe.fixture_id,
        CASE
            WHEN fe.type_developer_name = 'OWNGOAL' THEN fe.team_id
            ELSE fp_opp.team_id
        END                                      AS conceding_team_id,
        fe.minute + COALESCE(fe.extra_minute, 0) AS goal_minute
    FROM {{ ref('fixture_events') }} fe
    LEFT JOIN {{ ref('fixture_participants') }} fp_opp
        ON  fp_opp.fixture_id = fe.fixture_id
        AND fp_opp.team_id   != fe.team_id
    WHERE fe.type_developer_name IN ('GOAL', 'OWNGOAL')
      AND fe.team_id IS NOT NULL
      AND fe.minute  IS NOT NULL
),
-- Minute a substitute came ON (player_id = incoming player in SUBSTITUTION events)
gk_sub_minute AS (
    SELECT fixture_id, player_id, MIN(minute) AS minute_on
    FROM {{ ref('fixture_events') }}
    WHERE type_developer_name = 'SUBSTITUTION' AND player_id IS NOT NULL
    GROUP BY fixture_id, player_id
),
coaches AS (
    SELECT fixture_id, team_id, coach_id
    FROM {{ ref('fixture_coaches') }}
),
formations AS (
    SELECT fixture_id, team_id, formation
    FROM {{ ref('fixture_formations') }}
),
player_detail AS (
    SELECT DISTINCT ON (id)
        id AS player_id,
        detailed_position_name
    FROM {{ ref('players') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
lineup_minutes AS (
    SELECT fixture_id, player_id, MAX(value::INTEGER) AS minutes_played
    FROM {{ ref('fixture_lineup_details') }}
    WHERE type_id = 119
    GROUP BY fixture_id, player_id
),
lineup_base AS (
    SELECT DISTINCT ON (lu.fixture_id, lu.player_id)
        lu.fixture_id,
        lu.player_id,
        lu.team_id,
        lu.type_id             AS lineup_type_id,
        lu.position_id,
        lu.detailed_position_name,
        COALESCE(lm.minutes_played, 0) AS minutes_played
    FROM {{ ref('fixture_lineups') }} lu
    INNER JOIN finished_fixtures f ON f.fixture_id = lu.fixture_id
    LEFT JOIN lineup_minutes lm
        ON lm.fixture_id = lu.fixture_id AND lm.player_id = lu.player_id
    WHERE lu.player_id IS NOT NULL
      AND lu.team_id   IS NOT NULL
      AND (lu.type_id = 11 OR COALESCE(lm.minutes_played, 0) > 0)
    ORDER BY lu.fixture_id, lu.player_id, lu.type_id ASC
),
-- How many GKs played per team per fixture (determines whether to split goals)
gk_count_per_team AS (
    SELECT fixture_id, team_id, COUNT(*) AS gk_count
    FROM lineup_base
    WHERE position_id = 24
    GROUP BY fixture_id, team_id
),
-- Goals conceded per GK:
--   Single GK  → gets all team goals (avoids missing extra-time goals due to minutes_played rounding)
--   Multi  GK  → split by on-pitch window; starter cutoff = minutes_played, sub start = substitution minute
gk_goals_conceded AS (
    SELECT
        lb.fixture_id,
        lb.player_id,
        COUNT(gat.goal_minute) AS goals_conceded
    FROM lineup_base lb
    JOIN gk_count_per_team gct ON gct.fixture_id = lb.fixture_id AND gct.team_id = lb.team_id
    LEFT JOIN gk_sub_minute gsm ON gsm.fixture_id = lb.fixture_id AND gsm.player_id = lb.player_id
    LEFT JOIN goals_against_team gat
        ON  gat.fixture_id        = lb.fixture_id
        AND gat.conceding_team_id = lb.team_id
        AND (
            gct.gk_count = 1
            OR (
                gct.gk_count > 1
                AND gat.goal_minute > CASE
                        WHEN lb.lineup_type_id = 11 THEN 0
                        ELSE COALESCE(gsm.minute_on, GREATEST(0, 90 - lb.minutes_played))
                    END
                AND gat.goal_minute <= CASE
                        WHEN lb.lineup_type_id = 11 THEN lb.minutes_played
                        ELSE 200
                    END
            )
        )
    WHERE lb.position_id = 24
    GROUP BY lb.fixture_id, lb.player_id
),
stats AS (
    SELECT
        fixture_id,
        player_id,
        -- Attacking
        MAX(CASE WHEN type_id =   52 THEN value ELSE 0 END)::INTEGER  AS goals_scored,
        MAX(CASE WHEN type_id =  324 THEN value ELSE 0 END)::INTEGER  AS own_goals,
        MAX(CASE WHEN type_id =   79 THEN value ELSE 0 END)::INTEGER  AS assists,
        MAX(CASE WHEN type_id =   42 THEN value ELSE 0 END)::INTEGER  AS shots_total,
        MAX(CASE WHEN type_id =   86 THEN value ELSE 0 END)::INTEGER  AS shots_on_target,
        MAX(CASE WHEN type_id =   41 THEN value ELSE 0 END)::INTEGER  AS shots_off_target,
        MAX(CASE WHEN type_id =   58 THEN value ELSE 0 END)::INTEGER  AS shots_blocked,
        MAX(CASE WHEN type_id =   64 THEN value ELSE 0 END)::INTEGER  AS woodwork_hits,
        MAX(CASE WHEN type_id =  580 THEN value ELSE 0 END)::INTEGER  AS big_chances_created,
        MAX(CASE WHEN type_id =  581 THEN value ELSE 0 END)::INTEGER  AS big_chances_missed,
        MAX(CASE WHEN type_id = 9706 THEN value ELSE 0 END)::INTEGER  AS chances_created,
        -- Passing
        MAX(CASE WHEN type_id =   80 THEN value ELSE 0 END)::INTEGER  AS passes_total,
        MAX(CASE WHEN type_id =  116 THEN value ELSE 0 END)::INTEGER  AS passes_accurate,
        MAX(CASE WHEN type_id =  117 THEN value ELSE 0 END)::INTEGER  AS key_passes,
        MAX(CASE WHEN type_id = 27269 THEN value ELSE 0 END)::INTEGER AS passes_final_third,
        MAX(CASE WHEN type_id = 27272 THEN value ELSE 0 END)::INTEGER AS passes_backward,
        MAX(CASE WHEN type_id =  122 THEN value ELSE 0 END)::INTEGER  AS long_balls,
        MAX(CASE WHEN type_id =  123 THEN value ELSE 0 END)::INTEGER  AS long_balls_won,
        MAX(CASE WHEN type_id =   98 THEN value ELSE 0 END)::INTEGER  AS crosses_total,
        MAX(CASE WHEN type_id =   99 THEN value ELSE 0 END)::INTEGER  AS crosses_accurate,
        -- Defending
        MAX(CASE WHEN type_id =   78 THEN value ELSE 0 END)::INTEGER  AS tackles,
        MAX(CASE WHEN type_id = 27267 THEN value ELSE 0 END)::INTEGER AS tackles_won,
        MAX(CASE WHEN type_id =  101 THEN value ELSE 0 END)::INTEGER  AS clearances,
        MAX(CASE WHEN type_id =  100 THEN value ELSE 0 END)::INTEGER  AS interceptions,
        MAX(CASE WHEN type_id =  107 THEN value ELSE 0 END)::INTEGER  AS aerials_won,
        MAX(CASE WHEN type_id = 27266 THEN value ELSE 0 END)::INTEGER AS aerials_lost,
        MAX(CASE WHEN type_id =   97 THEN value ELSE 0 END)::INTEGER  AS blocks,
        MAX(CASE WHEN type_id = 27271 THEN value ELSE 0 END)::INTEGER AS balls_recovered,
        MAX(CASE WHEN type_id =  583 THEN value ELSE 0 END)::INTEGER  AS last_man_tackle,
        MAX(CASE WHEN type_id =  582 THEN value ELSE 0 END)::INTEGER  AS clearances_off_line,
        -- Duels & dribbling
        MAX(CASE WHEN type_id =  105 THEN value ELSE 0 END)::INTEGER  AS duels_total,
        MAX(CASE WHEN type_id =  106 THEN value ELSE 0 END)::INTEGER  AS duels_won,
        MAX(CASE WHEN type_id = 1491 THEN value ELSE 0 END)::INTEGER  AS duels_lost,
        MAX(CASE WHEN type_id =  108 THEN value ELSE 0 END)::INTEGER  AS dribbles_attempts,
        MAX(CASE WHEN type_id =  109 THEN value ELSE 0 END)::INTEGER  AS dribbles_completed,
        MAX(CASE WHEN type_id =  110 THEN value ELSE 0 END)::INTEGER  AS times_dribbled_past,
        MAX(CASE WHEN type_id =   94 THEN value ELSE 0 END)::INTEGER  AS dispossessed,
        -- Discipline
        MAX(CASE WHEN type_id =   56 THEN value ELSE 0 END)::INTEGER  AS fouls_committed,
        MAX(CASE WHEN type_id =   96 THEN value ELSE 0 END)::INTEGER  AS fouls_drawn,
        MAX(CASE WHEN type_id =   84 THEN value ELSE 0 END)::INTEGER  AS yellow_cards,
        MAX(CASE WHEN type_id =   85 THEN value ELSE 0 END)::INTEGER  AS yellow_red_cards,
        MAX(CASE WHEN type_id =   83 THEN value ELSE 0 END)::INTEGER  AS red_cards,
        MAX(CASE WHEN type_id =   51 THEN value ELSE 0 END)::INTEGER  AS offsides,
        -- Penalties
        MAX(CASE WHEN type_id =  115 THEN value ELSE 0 END)::INTEGER  AS penalty_won,
        MAX(CASE WHEN type_id =  114 THEN value ELSE 0 END)::INTEGER  AS penalty_committed,
        MAX(CASE WHEN type_id =  111 THEN value ELSE 0 END)::INTEGER  AS penalty_scored,
        MAX(CASE WHEN type_id =  112 THEN value ELSE 0 END)::INTEGER  AS penalty_missed,
        MAX(CASE WHEN type_id =  113 THEN value ELSE 0 END)::INTEGER  AS penalty_saved,
        -- Goalkeeping
        MAX(CASE WHEN type_id =   88 THEN value ELSE 0 END)::INTEGER  AS goals_conceded,
        MAX(CASE WHEN type_id =   57 THEN value ELSE 0 END)::INTEGER  AS saves,
        MAX(CASE WHEN type_id =  104 THEN value ELSE 0 END)::INTEGER  AS saves_inside_box,
        MAX(CASE WHEN type_id =  103 THEN value ELSE 0 END)::INTEGER  AS goalkeeper_punches,
        MAX(CASE WHEN type_id =  584 THEN value ELSE 0 END)::INTEGER  AS high_ball_claims,
        MAX(CASE WHEN type_id =  571 THEN value ELSE 0 END)::INTEGER  AS errors_leading_to_goal,
        MAX(CASE WHEN type_id = 48997 THEN value ELSE 0 END)::INTEGER AS errors_leading_to_shot,
        -- General
        MAX(CASE WHEN type_id = 27273 THEN value ELSE 0 END)::INTEGER AS possession_losses,
        MAX(CASE WHEN type_id =  118 THEN value ELSE NULL END)         AS rating
    FROM {{ ref('fixture_lineup_details') }}
    GROUP BY fixture_id, player_id
),
src AS (
    SELECT
        lb.fixture_id,
        lb.player_id,
        lb.team_id,
        lb.position_id,
        COALESCE(lb.detailed_position_name, pd.detailed_position_name) AS detailed_position_name,
        lb.minutes_played,
        ff.starting_at,
        ff.league_id,
        ff.venue_id,
        COALESCE(co.coach_id, NULL)    AS coach_id,
        fo.formation,
        CASE lb.lineup_type_id WHEN 11 THEN 1 ELSE 2 END AS appearance_type_sk,
        COALESCE(tc.team_side_sk, -1)  AS team_side_sk,
        tc.opponent_team_id,
        CASE
            WHEN tc.opponent_team_id IS NULL THEN -1
            WHEN COALESCE(ts_own.goals, 0) > COALESCE(ts_opp.goals, 0) THEN 1
            WHEN COALESCE(ts_own.goals, 0) = COALESCE(ts_opp.goals, 0) THEN 2
            ELSE 3
        END                            AS match_result_sk,
        -- Attacking
        COALESCE(s.goals_scored,       0) AS goals_scored,
        COALESCE(s.own_goals,          0) AS own_goals,
        COALESCE(s.assists,            0) AS assists,
        COALESCE(s.shots_total,        0) AS shots_total,
        COALESCE(s.shots_on_target,    0) AS shots_on_target,
        COALESCE(s.shots_off_target,   0) AS shots_off_target,
        COALESCE(s.shots_blocked,      0) AS shots_blocked,
        COALESCE(s.woodwork_hits,       0) AS woodwork_hits,
        COALESCE(s.big_chances_created,0) AS big_chances_created,
        COALESCE(s.big_chances_missed, 0) AS big_chances_missed,
        COALESCE(s.chances_created,    0) AS chances_created,
        -- Passing
        COALESCE(s.passes_total,       0) AS passes_total,
        COALESCE(s.passes_accurate,    0) AS passes_accurate,
        COALESCE(s.key_passes,         0) AS key_passes,
        COALESCE(s.passes_final_third, 0) AS passes_final_third,
        COALESCE(s.passes_backward,    0) AS passes_backward,
        COALESCE(s.long_balls,         0) AS long_balls,
        COALESCE(s.long_balls_won,     0) AS long_balls_won,
        COALESCE(s.crosses_total,      0) AS crosses_total,
        COALESCE(s.crosses_accurate,   0) AS crosses_accurate,
        -- Defending
        COALESCE(s.tackles,            0) AS tackles,
        COALESCE(s.tackles_won,        0) AS tackles_won,
        COALESCE(s.clearances,         0) AS clearances,
        COALESCE(s.interceptions,      0) AS interceptions,
        COALESCE(s.aerials_won,        0) AS aerials_won,
        COALESCE(s.aerials_lost,       0) AS aerials_lost,
        COALESCE(s.blocks,      0) AS blocks,
        COALESCE(s.balls_recovered,      0) AS balls_recovered,
        COALESCE(s.last_man_tackle,    0) AS last_man_tackle,
        COALESCE(s.clearances_off_line,  0) AS clearances_off_line,
        -- Duels & dribbling
        COALESCE(s.duels_total,        0) AS duels_total,
        COALESCE(s.duels_won,          0) AS duels_won,
        COALESCE(s.duels_lost,         0) AS duels_lost,
        COALESCE(s.dribbles_attempts,  0) AS dribbles_attempts,
        COALESCE(s.dribbles_completed,   0) AS dribbles_completed,
        COALESCE(s.times_dribbled_past,      0) AS times_dribbled_past,
        COALESCE(s.dispossessed,       0) AS dispossessed,
        -- Discipline
        COALESCE(s.fouls_committed,    0) AS fouls_committed,
        COALESCE(s.fouls_drawn,        0) AS fouls_drawn,
        COALESCE(s.yellow_cards,       0) AS yellow_cards,
        COALESCE(s.yellow_red_cards,   0) AS yellow_red_cards,
        COALESCE(s.red_cards,          0) AS red_cards,
        COALESCE(s.offsides,           0) AS offsides,
        -- Penalties
        COALESCE(s.penalty_won,        0) AS penalty_won,
        COALESCE(s.penalty_committed,  0) AS penalty_committed,
        COALESCE(s.penalty_scored,     0) AS penalty_scored,
        COALESCE(s.penalty_missed,     0) AS penalty_missed,
        COALESCE(s.penalty_saved,      0) AS penalty_saved,
        -- Goalkeeping (NULL for non-GKs; goals_conceded from event data to correctly handle GK substitutions)
        CASE WHEN lb.position_id = 24 THEN COALESCE(ggc.goals_conceded,   0) END AS goals_conceded,
        CASE WHEN lb.position_id = 24 THEN COALESCE(s.saves,              0) END AS saves,
        CASE WHEN lb.position_id = 24 THEN COALESCE(s.saves_inside_box,   0) END AS saves_inside_box,
        CASE WHEN lb.position_id = 24 THEN COALESCE(s.goalkeeper_punches, 0) END AS goalkeeper_punches,
        CASE WHEN lb.position_id = 24 THEN COALESCE(s.high_ball_claims,   0) END AS high_ball_claims,
        COALESCE(s.errors_leading_to_goal,0) AS errors_leading_to_goal,
        COALESCE(s.errors_leading_to_shot,0) AS errors_leading_to_shot,
        -- General
        COALESCE(s.possession_losses,    0) AS possession_losses,
        s.rating
    FROM lineup_base lb
    INNER JOIN finished_fixtures ff  ON ff.fixture_id  = lb.fixture_id
    LEFT JOIN team_context  tc       ON tc.fixture_id  = lb.fixture_id AND tc.team_id = lb.team_id
    LEFT JOIN team_scores   ts_own   ON ts_own.fixture_id = lb.fixture_id AND ts_own.team_id = lb.team_id
    LEFT JOIN team_scores   ts_opp   ON ts_opp.fixture_id = lb.fixture_id AND ts_opp.team_id = tc.opponent_team_id
    LEFT JOIN stats              s   ON s.fixture_id   = lb.fixture_id AND s.player_id = lb.player_id
    LEFT JOIN gk_goals_conceded  ggc ON ggc.fixture_id = lb.fixture_id AND ggc.player_id = lb.player_id
    LEFT JOIN player_detail       pd ON pd.player_id   = lb.player_id
    LEFT JOIN coaches       co       ON co.fixture_id  = lb.fixture_id AND co.team_id  = lb.team_id
    LEFT JOIN formations    fo       ON fo.fixture_id  = lb.fixture_id AND fo.team_id  = lb.team_id
)
SELECT
    COALESCE(dd.date_sk,           -1) AS date_sk,
    COALESCE(dt_time.time_sk,      -1) AS time_sk,
    COALESCE(dm.match_sk,          -1) AS match_sk,
    COALESCE(dp.player_sk,         -1) AS player_sk,
    COALESCE(dteam.team_sk,        -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk,-1) AS opponent_team_sk,
    COALESCE(dl.league_sk,         -1) AS league_sk,
    COALESCE(ds.stadium_sk,        -1) AS stadium_sk,
    COALESCE(dr.referee_sk,        -1) AS referee_sk,
    COALESCE(dc.coach_sk,          -1) AS coach_sk,
    COALESCE(df.formation_sk,      -1) AS formation_sk,
    COALESCE(dpos.position_sk,     -1) AS position_sk,
    src.team_side_sk,
    src.match_result_sk,
    src.appearance_type_sk,
    src.minutes_played,
    src.goals_scored,
    src.own_goals,
    src.assists,
    src.shots_total,
    src.shots_on_target,
    src.shots_off_target,
    src.shots_blocked,
    src.woodwork_hits,
    src.big_chances_created,
    src.big_chances_missed,
    src.chances_created,
    src.passes_total,
    src.passes_accurate,
    src.key_passes,
    src.passes_final_third,
    src.passes_backward,
    src.long_balls,
    src.long_balls_won,
    src.crosses_total,
    src.crosses_accurate,
    src.tackles,
    src.tackles_won,
    src.clearances,
    src.interceptions,
    src.aerials_won,
    src.aerials_lost,
    src.blocks,
    src.balls_recovered,
    src.last_man_tackle,
    src.clearances_off_line,
    src.duels_total,
    src.duels_won,
    src.duels_lost,
    src.dribbles_attempts,
    src.dribbles_completed,
    src.times_dribbled_past,
    src.dispossessed,
    src.fouls_committed,
    src.fouls_drawn,
    src.yellow_cards,
    src.yellow_red_cards,
    src.red_cards,
    src.offsides,
    src.penalty_won,
    src.penalty_committed,
    src.penalty_scored,
    src.penalty_missed,
    src.penalty_saved,
    src.goals_conceded,
    src.saves,
    src.saves_inside_box,
    src.goalkeeper_punches,
    src.high_ball_claims,
    src.errors_leading_to_goal,
    src.errors_leading_to_shot,
    src.possession_losses,
    src.rating
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk      = EXTRACT(hour FROM src.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::INTEGER
LEFT JOIN {{ ref('dim_match') }}         dm      ON dm.match_id          = src.fixture_id
LEFT JOIN {{ ref('dim_player') }}        dp      ON dp.player_id         = src.player_id
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id        = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id         = src.league_id
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_id        = src.venue_id
LEFT JOIN main_referee                   mr      ON mr.fixture_id        = src.fixture_id
LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_id        = mr.referee_id
LEFT JOIN {{ ref('dim_coach') }}         dc      ON dc.coach_id          = src.coach_id
LEFT JOIN {{ ref('dim_formation') }}     df      ON df.formation         = src.formation
LEFT JOIN {{ ref('dim_position') }}      dpos ON dpos.position_name = src.detailed_position_name
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
