{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'team_side_sk']
    )
}}

WITH fixture_teams AS (
    SELECT
        f.fixture_id,
        (f.kick_off AT TIME ZONE 'Europe/Copenhagen')::DATE    AS match_date,
        EXTRACT(hour FROM f.kick_off AT TIME ZONE 'Europe/Copenhagen')::INTEGER AS kick_off_hour,
        f.league_id,
        f.referee,
        f.venue_id,
        f.home_team_id                            AS team_id,
        f.away_team_id                            AS opponent_id,
        1                                         AS side_sk,
        f.goals_home                              AS goals_scored,
        f.goals_away                              AS goals_conceded,
        f.score_ht_home                           AS goals_ht_scored,
        f.score_ht_away                           AS goals_ht_conceded,
        f.status_short
    FROM {{ ref('fixtures') }} f
    UNION ALL
    SELECT
        f.fixture_id,
        (f.kick_off AT TIME ZONE 'Europe/Copenhagen')::DATE,
        EXTRACT(hour FROM f.kick_off AT TIME ZONE 'Europe/Copenhagen')::INTEGER,
        f.league_id,
        f.referee,
        f.venue_id,
        f.away_team_id,
        f.home_team_id,
        2,
        f.goals_away,
        f.goals_home,
        f.score_ht_away,
        f.score_ht_home,
        f.status_short
    FROM {{ ref('fixtures') }} f
),
joined AS (
    SELECT
        d.date_sk,
        COALESCE(t.time_sk,     -1)  AS time_sk,
        COALESCE(tm.team_sk,    -1)  AS team_sk,
        COALESCE(opp.team_sk,   -1)  AS opponent_team_sk,
        COALESCE(l.league_sk,   -1)  AS league_sk,
        COALESCE(st.stadium_sk, -1)  AS stadium_sk,
        COALESCE(ref.referee_sk,-1)  AS referee_sk,
        COALESCE(m.match_sk,    -1)  AS match_sk,
        ft.side_sk                   AS team_side_sk,
        CASE
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  > ft.goals_conceded THEN 1
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  = ft.goals_conceded THEN 2
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  < ft.goals_conceded THEN 3
            WHEN ft.status_short IN ('NS', 'TBD', '1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE') THEN 4
            WHEN ft.status_short IN ('PST', 'CANC', 'ABD', 'AWD', 'WO', 'SUSP', 'INT')        THEN -2
            ELSE -1
        END                          AS match_result_sk,
        CASE
            WHEN m.match_round_type IN ('Regular Season', 'Championship Group', 'Relegation Group')
                 AND ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  > ft.goals_conceded THEN 3
            WHEN m.match_round_type IN ('Regular Season', 'Championship Group', 'Relegation Group')
                 AND ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  = ft.goals_conceded THEN 1
            WHEN m.match_round_type IN ('Regular Season', 'Championship Group', 'Relegation Group')
                 AND ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  < ft.goals_conceded THEN 0
            ELSE NULL
        END                          AS points_earned,
        ft.goals_scored,
        ft.goals_conceded,
        ft.goals_ht_scored,
        ft.goals_ht_conceded,
        s.shots_on_goal,
        s.shots_off_goal,
        s.total_shots,
        s.blocked_shots,
        s.shots_insidebox,
        s.shots_outsidebox,
        s.ball_possession_pct,
        s.total_passes,
        s.passes_accurate,
        s.fouls,
        s.corner_kicks,
        s.offsides,
        s.yellow_cards,
        s.red_cards,
        s.goalkeeper_saves,
        s.expected_goals
    FROM fixture_teams ft
    JOIN      {{ ref('dim_date')    }} d   ON d.date           = ft.match_date
    LEFT JOIN {{ ref('dim_time')    }} t   ON t.time_sk        = ft.kick_off_hour
    LEFT JOIN {{ ref('dim_team')    }} tm  ON tm.team_id       = ft.team_id
    LEFT JOIN {{ ref('dim_team')    }} opp ON opp.team_id      = ft.opponent_id
    LEFT JOIN {{ ref('dim_league')  }} l   ON l.league_id      = ft.league_id
    LEFT JOIN {{ ref('dim_stadium') }} st  ON st.stadium_id    = ft.venue_id
    LEFT JOIN {{ ref('dim_referee') }} ref ON ref.referee_name = ft.referee
    LEFT JOIN {{ ref('dim_match')   }} m   ON m.match_id       = ft.fixture_id
    LEFT JOIN {{ ref('fixture_statistics') }} s
                                             ON s.fixture_id   = ft.fixture_id
                                            AND s.team_id      = ft.team_id
    WHERE m.match_round_type IN ('Regular Season', 'Championship Group', 'Relegation Group')
)
SELECT * FROM joined
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
