WITH finished_fixtures AS (
    SELECT id AS fixture_id
    FROM {{ ref('fixtures') }}
    WHERE state_developer_name IN ('FT', 'FT_PEN')
),
minutes AS (
    SELECT fixture_id, player_id, value::INTEGER AS minutes_played
    FROM {{ ref('fixture_lineup_details') }}
    WHERE type_id = 119
),
lineup_base AS (
    SELECT
        lu.fixture_id,
        lu.player_id,
        lu.team_id,
        lu.type_id                            AS lineup_type_id,
        COALESCE(m.minutes_played, 0)         AS minutes_played
    FROM {{ ref('fixture_lineups') }} lu
    INNER JOIN finished_fixtures f ON f.fixture_id = lu.fixture_id
    LEFT JOIN minutes m ON m.fixture_id = lu.fixture_id AND m.player_id = lu.player_id
    WHERE lu.player_id IS NOT NULL
      AND lu.team_id   IS NOT NULL
      AND (lu.type_id = 11 OR COALESCE(m.minutes_played, 0) > 0)
),
stats AS (
    SELECT
        fixture_id, player_id,
        MAX(CASE WHEN type_id =  52 THEN value ELSE 0 END)::INTEGER  AS goals_scored,
        MAX(CASE WHEN type_id =  79 THEN value ELSE 0 END)::INTEGER  AS assists,
        MAX(CASE WHEN type_id =  42 THEN value ELSE 0 END)::INTEGER  AS shots_total,
        MAX(CASE WHEN type_id =  86 THEN value ELSE 0 END)::INTEGER  AS shots_on_target,
        MAX(CASE WHEN type_id =  80 THEN value ELSE 0 END)::INTEGER  AS passes,
        MAX(CASE WHEN type_id = 116 THEN value ELSE 0 END)::INTEGER  AS accurate_passes,
        MAX(CASE WHEN type_id = 117 THEN value ELSE 0 END)::INTEGER  AS key_passes,
        MAX(CASE WHEN type_id = 118 THEN value ELSE NULL END)         AS rating,
        MAX(CASE WHEN type_id = 120 THEN value ELSE 0 END)::INTEGER  AS touches,
        MAX(CASE WHEN type_id =  78 THEN value ELSE 0 END)::INTEGER  AS tackles,
        MAX(CASE WHEN type_id = 100 THEN value ELSE 0 END)::INTEGER  AS interceptions,
        MAX(CASE WHEN type_id = 105 THEN value ELSE 0 END)::INTEGER  AS duels_total,
        MAX(CASE WHEN type_id = 106 THEN value ELSE 0 END)::INTEGER  AS duels_won,
        MAX(CASE WHEN type_id = 108 THEN value ELSE 0 END)::INTEGER  AS dribbles_attempted,
        MAX(CASE WHEN type_id = 109 THEN value ELSE 0 END)::INTEGER  AS dribbles_succeeded,
        MAX(CASE WHEN type_id = 101 THEN value ELSE 0 END)::INTEGER  AS clearances,
        MAX(CASE WHEN type_id = 122 THEN value ELSE 0 END)::INTEGER  AS long_balls,
        MAX(CASE WHEN type_id =  56 THEN value ELSE 0 END)::INTEGER  AS fouls_committed,
        MAX(CASE WHEN type_id =  96 THEN value ELSE 0 END)::INTEGER  AS fouls_drawn,
        MAX(CASE WHEN type_id =  51 THEN value ELSE 0 END)::INTEGER  AS offsides,
        MAX(CASE WHEN type_id =  57 THEN value ELSE 0 END)::INTEGER  AS saves,
        MAX(CASE WHEN type_id = 580 THEN value ELSE 0 END)::INTEGER  AS big_chances_created,
        MAX(CASE WHEN type_id = 581 THEN value ELSE 0 END)::INTEGER  AS big_chances_missed
    FROM {{ ref('fixture_lineup_details') }}
    GROUP BY fixture_id, player_id
),
cards AS (
    SELECT
        e.fixture_id, e.player_id, e.team_id,
        SUM(CASE WHEN e.type_id = 15 THEN 1 ELSE 0 END) AS own_goals,
        SUM(CASE WHEN e.type_id = 16 THEN 1 ELSE 0 END) AS goals_from_penalty,
        SUM(CASE WHEN e.type_id = 19 THEN 1 ELSE 0 END) AS yellow_cards,
        SUM(CASE WHEN e.type_id = 20 THEN 1 ELSE 0 END) AS red_cards,
        SUM(CASE WHEN e.type_id = 21 THEN 1 ELSE 0 END) AS yellow_red_cards
    FROM {{ ref('fixture_events') }} e
    INNER JOIN finished_fixtures f ON f.fixture_id = e.fixture_id
    WHERE e.player_id IS NOT NULL AND e.rescinded IS NOT TRUE
    GROUP BY e.fixture_id, e.player_id, e.team_id
),
src AS (
    SELECT
        lb.fixture_id,
        lb.player_id,
        lb.team_id,
        lb.minutes_played,
        CASE lb.lineup_type_id WHEN 11 THEN 1 ELSE 2 END AS appearance_type_sk,
        COALESCE(s.goals_scored,        0)  AS goals_scored,
        COALESCE(c.own_goals,           0)  AS own_goals,
        COALESCE(c.goals_from_penalty,  0)  AS goals_from_penalty,
        COALESCE(s.assists,             0)  AS assists,
        COALESCE(c.yellow_cards,        0)  AS yellow_cards,
        COALESCE(c.red_cards,           0)  AS red_cards,
        COALESCE(c.yellow_red_cards,    0)  AS yellow_red_cards,
        COALESCE(s.shots_total,         0)  AS shots_total,
        COALESCE(s.shots_on_target,     0)  AS shots_on_target,
        COALESCE(s.passes,              0)  AS passes,
        COALESCE(s.accurate_passes,     0)  AS accurate_passes,
        COALESCE(s.key_passes,          0)  AS key_passes,
        s.rating,
        COALESCE(s.touches,             0)  AS touches,
        COALESCE(s.tackles,             0)  AS tackles,
        COALESCE(s.interceptions,       0)  AS interceptions,
        COALESCE(s.duels_total,         0)  AS duels_total,
        COALESCE(s.duels_won,           0)  AS duels_won,
        COALESCE(s.dribbles_attempted,  0)  AS dribbles_attempted,
        COALESCE(s.dribbles_succeeded,  0)  AS dribbles_succeeded,
        COALESCE(s.clearances,          0)  AS clearances,
        COALESCE(s.long_balls,          0)  AS long_balls,
        COALESCE(s.fouls_committed,     0)  AS fouls_committed,
        COALESCE(s.fouls_drawn,         0)  AS fouls_drawn,
        COALESCE(s.offsides,            0)  AS offsides,
        COALESCE(s.saves,               0)  AS saves,
        COALESCE(s.big_chances_created, 0)  AS big_chances_created,
        COALESCE(s.big_chances_missed,  0)  AS big_chances_missed
    FROM lineup_base lb
    LEFT JOIN stats s ON s.fixture_id = lb.fixture_id AND s.player_id = lb.player_id
    LEFT JOIN cards c ON c.fixture_id = lb.fixture_id AND c.player_id  = lb.player_id
                     AND c.team_id    = lb.team_id
)
SELECT
    COALESCE(dm.match_sk,  -1) AS match_sk,
    COALESCE(dp.player_sk, -1) AS player_sk,
    COALESCE(dt.team_sk,   -1) AS team_sk,
    src.appearance_type_sk,
    src.minutes_played,
    src.goals_scored,
    src.own_goals,
    src.goals_from_penalty,
    src.assists,
    src.yellow_cards,
    src.red_cards,
    src.yellow_red_cards,
    src.shots_total,
    src.shots_on_target,
    src.passes,
    src.accurate_passes,
    src.key_passes,
    src.rating,
    src.touches,
    src.tackles,
    src.interceptions,
    src.duels_total,
    src.duels_won,
    src.dribbles_attempted,
    src.dribbles_succeeded,
    src.clearances,
    src.long_balls,
    src.fouls_committed,
    src.fouls_drawn,
    src.offsides,
    src.saves,
    src.big_chances_created,
    src.big_chances_missed
FROM src
LEFT JOIN {{ ref('dim_match') }}  dm ON dm.match_id  = src.fixture_id
LEFT JOIN {{ ref('dim_player') }} dp ON dp.player_id = src.player_id
LEFT JOIN {{ ref('dim_team') }}   dt ON dt.team_id   = src.team_id
