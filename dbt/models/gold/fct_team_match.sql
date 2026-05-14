{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'team_side_sk']
    )
}}

WITH all_fixtures AS (
    SELECT
        f.id       AS fixture_id,
        f.league_id,
        f.venue_id,
        f.starting_at,
        sg.type_developer_name AS stage_type,
        f.state_developer_name IN ('FT', 'FT_PEN', 'AET') AS is_finished
    FROM {{ ref('fixtures') }} f
    LEFT JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
),
coaches AS (
    SELECT fixture_id, team_id, coach_id
    FROM {{ ref('fixture_coaches') }}
),
formations AS (
    SELECT fixture_id, team_id, formation
    FROM {{ ref('fixture_formations') }}
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
       AND opp.location  != p.location
),
scores AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN description = 'CURRENT'  THEN goals END) AS goals_scored,
        MAX(CASE WHEN description = '1ST_HALF' THEN goals END) AS goals_ht_scored
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, team_id
),
stats AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN type_id = 34 THEN value::INTEGER      END) AS corner_kicks,
        MAX(CASE WHEN type_id = 45 THEN value::DECIMAL(5,2) END) AS ball_possession_pct,
        MAX(CASE WHEN type_id = 83 THEN value::INTEGER      END) AS red_cards,
        MAX(CASE WHEN type_id = 84 THEN value::INTEGER      END) AS yellow_cards
    FROM {{ ref('fixture_statistics') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    SELECT fixture_id, referee_id
    FROM {{ ref('fixture_referees') }}
    WHERE type_id = 6
),
src AS (
    SELECT
        f.fixture_id,
        f.league_id,
        f.starting_at,
        f.venue_id,
        f.stage_type,
        mt.team_id,
        mt.location,
        mt.opponent_team_id,
        mr.referee_id,
        f.is_finished,
        co.coach_id,
        fo.formation,
        CASE WHEN f.is_finished THEN COALESCE(sc.goals_scored,     0) END AS goals_scored,
        CASE WHEN f.is_finished THEN COALESCE(osc.goals_scored,    0) END AS goals_conceded,
        CASE WHEN f.is_finished THEN COALESCE(sc.goals_ht_scored,  0) END AS goals_ht_scored,
        CASE WHEN f.is_finished THEN COALESCE(osc.goals_ht_scored, 0) END AS goals_ht_conceded,
        CASE WHEN f.is_finished THEN COALESCE(st.corner_kicks,     0) END AS corner_kicks,
        CASE WHEN f.is_finished THEN st.ball_possession_pct          END AS ball_possession_pct,
        CASE WHEN f.is_finished THEN COALESCE(st.yellow_cards,     0) END AS yellow_cards,
        CASE WHEN f.is_finished THEN COALESCE(st.red_cards,        0) END AS red_cards
    FROM all_fixtures f
    JOIN  match_teams       mt   ON mt.fixture_id  = f.fixture_id
    LEFT JOIN scores        sc   ON sc.fixture_id  = f.fixture_id AND sc.team_id  = mt.team_id
    LEFT JOIN scores        osc  ON osc.fixture_id = f.fixture_id AND osc.team_id = mt.opponent_team_id
    LEFT JOIN stats         st   ON st.fixture_id  = f.fixture_id AND st.team_id  = mt.team_id
    LEFT JOIN main_referee  mr   ON mr.fixture_id  = f.fixture_id
    LEFT JOIN coaches       co   ON co.fixture_id  = f.fixture_id AND co.team_id = mt.team_id
    LEFT JOIN formations    fo   ON fo.fixture_id  = f.fixture_id AND fo.team_id = mt.team_id
)
SELECT
    COALESCE(dd.date_sk,           -1) AS date_sk,
    COALESCE(dt_time.time_sk,      -1) AS time_sk,
    COALESCE(dteam.team_sk,        -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk,-1) AS opponent_team_sk,
    COALESCE(dl.league_sk,         -1) AS league_sk,
    COALESCE(ds.stadium_sk,        -1) AS stadium_sk,
    COALESCE(dr.referee_sk,        -1) AS referee_sk,
    COALESCE(dm.match_sk,          -1) AS match_sk,
    COALESCE(dc.coach_sk,          -1) AS coach_sk,
    COALESCE(df.formation_sk,      -1) AS formation_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                AS team_side_sk,
    CASE
        WHEN NOT src.is_finished                        THEN 4
        WHEN src.goals_scored > src.goals_conceded      THEN 1
        WHEN src.goals_scored = src.goals_conceded      THEN 2
        ELSE                                                 3
    END                                AS match_result_sk,
    CASE
        WHEN NOT src.is_finished                                                       THEN NULL
        WHEN src.stage_type = 'GROUP_STAGE' AND src.goals_scored > src.goals_conceded THEN 3
        WHEN src.stage_type = 'GROUP_STAGE' AND src.goals_scored = src.goals_conceded THEN 1
        WHEN src.stage_type = 'GROUP_STAGE'                                            THEN 0
        ELSE NULL
    END                                AS points_earned,
    src.goals_scored,
    src.goals_conceded,
    src.goals_ht_scored,
    src.goals_ht_conceded,
    src.corner_kicks,
    src.ball_possession_pct,
    src.yellow_cards,
    src.red_cards
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk      = EXTRACT(hour FROM src.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::INTEGER
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id        = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id         = src.league_id
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_id        = src.venue_id
LEFT JOIN {{ ref('referee_id_overrides') }} rio    ON rio.referee_id      = src.referee_id
LEFT JOIN {{ ref('dim_referee') }}           dr    ON dr.referee_id        = COALESCE(rio.canonical_referee_id, src.referee_id)
LEFT JOIN {{ ref('dim_match') }}          dm      ON dm.match_id          = src.fixture_id
LEFT JOIN {{ ref('dim_coach') }}          dc      ON dc.coach_id          = src.coach_id
LEFT JOIN {{ ref('dim_formation') }}      df      ON df.formation         = src.formation
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
