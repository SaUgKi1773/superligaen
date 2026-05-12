WITH finished_fixtures AS (
    SELECT id AS fixture_id
    FROM {{ ref('fixtures') }}
    WHERE state_developer_name IN ('FT', 'FT_PEN')
),
raw_events AS (
    SELECT
        e.fixture_id,
        e.player_id,
        e.team_id,
        e.type_id,
        e.related_player_id
    FROM {{ ref('fixture_events') }} e
    INNER JOIN finished_fixtures f ON f.fixture_id = e.fixture_id
    WHERE e.player_id IS NOT NULL
      AND e.team_id   IS NOT NULL
      AND e.rescinded IS NOT TRUE
),
-- All distinct player appearances (players with any direct event in the match)
players AS (
    SELECT DISTINCT fixture_id, player_id, team_id
    FROM raw_events
),
-- Aggregate direct event counts per player per match
direct AS (
    SELECT
        fixture_id,
        player_id,
        team_id,
        SUM(CASE WHEN type_id = 14 THEN 1 ELSE 0 END) AS goals_scored,
        SUM(CASE WHEN type_id = 15 THEN 1 ELSE 0 END) AS own_goals,
        SUM(CASE WHEN type_id = 16 THEN 1 ELSE 0 END) AS goals_from_penalty,
        SUM(CASE WHEN type_id = 19 THEN 1 ELSE 0 END) AS yellow_cards,
        SUM(CASE WHEN type_id = 20 THEN 1 ELSE 0 END) AS red_cards,
        SUM(CASE WHEN type_id = 21 THEN 1 ELSE 0 END) AS yellow_red_cards
    FROM raw_events
    GROUP BY fixture_id, player_id, team_id
),
-- Assists: player is the related_player_id on a goal or penalty goal event
assists AS (
    SELECT
        e.fixture_id,
        e.related_player_id AS player_id,
        COUNT(*)             AS assists
    FROM {{ ref('fixture_events') }} e
    INNER JOIN finished_fixtures f ON f.fixture_id = e.fixture_id
    WHERE e.type_id IN (14, 16)
      AND e.related_player_id IS NOT NULL
      AND e.rescinded IS NOT TRUE
    GROUP BY e.fixture_id, e.related_player_id
),
-- Substitute entries: player came ON as a sub (they are the related_player_id on type_id=18)
sub_entries AS (
    SELECT DISTINCT
        e.fixture_id,
        e.related_player_id AS player_id
    FROM {{ ref('fixture_events') }} e
    INNER JOIN finished_fixtures f ON f.fixture_id = e.fixture_id
    WHERE e.type_id = 18
      AND e.related_player_id IS NOT NULL
),
src AS (
    SELECT
        p.fixture_id,
        p.player_id,
        p.team_id,
        COALESCE(d.goals_scored,       0) AS goals_scored,
        COALESCE(d.own_goals,          0) AS own_goals,
        COALESCE(d.goals_from_penalty, 0) AS goals_from_penalty,
        COALESCE(a.assists,            0) AS assists,
        COALESCE(d.yellow_cards,       0) AS yellow_cards,
        COALESCE(d.red_cards,          0) AS red_cards,
        COALESCE(d.yellow_red_cards,   0) AS yellow_red_cards,
        CASE WHEN se.player_id IS NOT NULL THEN 2 ELSE 1 END AS appearance_type_sk
    FROM players p
    LEFT JOIN direct      d  ON d.fixture_id  = p.fixture_id AND d.player_id = p.player_id AND d.team_id = p.team_id
    LEFT JOIN assists     a  ON a.fixture_id  = p.fixture_id AND a.player_id = p.player_id
    LEFT JOIN sub_entries se ON se.fixture_id = p.fixture_id AND se.player_id = p.player_id
)
SELECT
    COALESCE(dm.match_sk,  -1)  AS match_sk,
    COALESCE(dp.player_sk, -1)  AS player_sk,
    COALESCE(dt.team_sk,   -1)  AS team_sk,
    src.appearance_type_sk,
    src.goals_scored,
    src.own_goals,
    src.goals_from_penalty,
    src.assists,
    src.yellow_cards,
    src.red_cards,
    src.yellow_red_cards
FROM src
LEFT JOIN {{ ref('dim_match') }}  dm ON dm.match_id  = src.fixture_id
LEFT JOIN {{ ref('dim_player') }} dp ON dp.player_id = src.player_id
LEFT JOIN {{ ref('dim_team') }}   dt ON dt.team_id   = src.team_id
