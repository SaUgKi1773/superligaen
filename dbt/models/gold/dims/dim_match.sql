WITH participants_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN location = 'home' THEN team_name       END) AS home_team_name,
        MAX(CASE WHEN location = 'home' THEN team_short_code END) AS home_team_code,
        MAX(CASE WHEN location = 'away' THEN team_name       END) AS away_team_name,
        MAX(CASE WHEN location = 'away' THEN team_short_code END) AS away_team_code
    FROM {{ ref('fixture_participants') }}
    GROUP BY fixture_id
),
scores_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'home' THEN goals END) AS goals_home,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'away' THEN goals END) AS goals_away
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id
),
src AS (
    SELECT
        f.id                                                                     AS match_id,
        se.name                                                                  AS season,
        sg.name                                                                  AS match_round_type,
        f.round_name                                                             AS match_round_name,
        TRY_CAST(f.round_name AS INTEGER)                                        AS match_round_number,
        COALESCE(pp.home_team_name, '') || ' - ' || COALESCE(pp.away_team_name, '') AS match_name,
        COALESCE(pp.home_team_code, pp.home_team_name, '')
            || ' - ' || COALESCE(pp.away_team_code, pp.away_team_name, '')      AS match_short_name,
        CASE WHEN f.state_developer_name IN ('FT', 'FT_PEN')
             THEN sp.goals_home::VARCHAR || ' - ' || sp.goals_away::VARCHAR
        END                                                                      AS match_result,
        lpad(EXTRACT(hour   FROM f.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::VARCHAR, 2, '0')
            || ':'
            || lpad(EXTRACT(minute FROM f.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::VARCHAR, 2, '0')
                                                                                 AS kick_off_time,
        f.state_name                                                             AS match_status
    FROM {{ ref('fixtures') }} f
    LEFT JOIN {{ ref('seasons') }}     se ON se.id  = f.season_id
    LEFT JOIN {{ ref('stages') }}      sg ON sg.id  = f.stage_id
    LEFT JOIN participants_pivot       pp ON pp.fixture_id = f.id
    LEFT JOIN scores_pivot             sp ON sp.fixture_id = f.id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY match_id) AS match_sk,
    match_id,
    season,
    match_round_type,
    match_round_name,
    match_round_number,
    match_name,
    match_short_name,
    match_result,
    kick_off_time,
    match_status
FROM src
UNION ALL SELECT -1, NULL, NULL, NULL, NULL, NULL, 'Unknown Match',        NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, NULL, NULL, NULL, NULL, 'Not Applicable Match', NULL, NULL, NULL, NULL
