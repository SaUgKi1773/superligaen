WITH finished_fixtures AS (
    SELECT
        id             AS fixture_id,
        season_id,
        stage_id,
        venue_id,
        starting_at,
        state_developer_name
    FROM {{ ref('fixtures') }}
    WHERE state_developer_name IN ('FT', 'FT_PEN')
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
match_teams AS (
    SELECT
        p.fixture_id,
        p.team_id,
        p.location,
        opp.team_id AS opponent_team_id
    FROM participants p
    JOIN participants opp
        ON opp.fixture_id = p.fixture_id
       AND opp.team_id != p.team_id
),
scores AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN description = 'CURRENT'  THEN goals END) AS goals_scored,
        MAX(CASE WHEN description = '1ST_HALF' THEN goals END) AS goals_scored_ht
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, team_id
),
stats AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN type_id = 34 THEN value::INTEGER         END) AS corners,
        MAX(CASE WHEN type_id = 45 THEN value::DECIMAL(5, 2)   END) AS ball_possession_pct,
        MAX(CASE WHEN type_id = 83 THEN value::INTEGER         END) AS red_cards,
        MAX(CASE WHEN type_id = 84 THEN value::INTEGER         END) AS yellow_cards,
        MAX(CASE WHEN type_id = 85 THEN value::INTEGER         END) AS yellow_red_cards
    FROM {{ ref('fixture_statistics') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    SELECT DISTINCT ON (fixture_id)
        fixture_id,
        referee_id
    FROM {{ ref('fixture_referees') }}
    ORDER BY fixture_id, id
),
src AS (
    SELECT
        f.fixture_id,
        f.starting_at,
        f.venue_id,
        mt.team_id,
        mt.location,
        mt.opponent_team_id,
        mr.referee_id,
        COALESCE(sc.goals_scored,    0)        AS goals_scored,
        COALESCE(opp_sc.goals_scored, 0)       AS goals_conceded,
        COALESCE(sc.goals_scored_ht,  0)       AS goals_scored_ht,
        COALESCE(opp_sc.goals_scored_ht, 0)    AS goals_conceded_ht,
        COALESCE(st.corners,          0)       AS corners,
        st.ball_possession_pct,
        COALESCE(st.yellow_cards,     0)       AS yellow_cards,
        COALESCE(st.yellow_red_cards, 0)       AS yellow_red_cards,
        COALESCE(st.red_cards,        0)       AS red_cards
    FROM finished_fixtures f
    JOIN match_teams      mt     ON mt.fixture_id      = f.fixture_id
    LEFT JOIN scores      sc     ON sc.fixture_id      = f.fixture_id AND sc.team_id = mt.team_id
    LEFT JOIN scores      opp_sc ON opp_sc.fixture_id  = f.fixture_id AND opp_sc.team_id = mt.opponent_team_id
    LEFT JOIN stats       st     ON st.fixture_id      = f.fixture_id AND st.team_id = mt.team_id
    LEFT JOIN main_referee mr    ON mr.fixture_id      = f.fixture_id
)
SELECT
    COALESCE(dm.match_sk,    -1)  AS match_sk,
    COALESCE(dd.date_sk,     -1)  AS date_sk,
    COALESCE(dt.team_sk,     -1)  AS team_sk,
    COALESCE(dot.opponent_team_sk, -1) AS opponent_team_sk,
    COALESCE(dr.referee_sk,  -1)  AS referee_sk,
    COALESCE(ds.stadium_sk,  -1)  AS stadium_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                           AS team_side_sk,
    CASE
        WHEN src.goals_scored > src.goals_conceded THEN 1   -- Win
        WHEN src.goals_scored = src.goals_conceded THEN 2   -- Draw
        ELSE                                            3   -- Loss
    END                           AS match_result_sk,
    src.goals_scored,
    src.goals_conceded,
    src.goals_scored_ht,
    src.goals_conceded_ht,
    src.corners,
    src.ball_possession_pct,
    src.yellow_cards,
    src.yellow_red_cards,
    src.red_cards,
    CASE
        WHEN src.goals_scored > src.goals_conceded THEN 3
        WHEN src.goals_scored = src.goals_conceded THEN 1
        ELSE                                            0
    END                           AS points_earned
FROM src
LEFT JOIN {{ ref('dim_match') }}         dm  ON dm.match_id          = src.fixture_id
LEFT JOIN {{ ref('dim_date') }}          dd  ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_team') }}          dt  ON dt.team_id           = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dot ON dot.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_referee') }}       dr  ON dr.referee_id        = src.referee_id
LEFT JOIN {{ ref('dim_stadium') }}       ds  ON ds.stadium_id        = src.venue_id
