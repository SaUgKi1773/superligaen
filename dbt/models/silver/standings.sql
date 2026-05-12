SELECT
    s.id,
    (s.raw_json->>'participant_id')::INTEGER    AS team_id,
    (s.raw_json->>'league_id')::INTEGER         AS league_id,
    (s.raw_json->>'season_id')::INTEGER         AS season_id,
    (s.raw_json->>'stage_id')::INTEGER          AS stage_id,
    (s.raw_json->>'group_id')::INTEGER          AS group_id,
    (s.raw_json->>'round_id')::INTEGER          AS round_id,
    (s.raw_json->>'standing_rule_id')::INTEGER  AS standing_rule_id,
    (s.raw_json->>'position')::INTEGER          AS position,
    s.raw_json->>'result'                       AS result,
    (s.raw_json->>'points')::INTEGER            AS points,
    s.raw_json->'participant'->>'name'          AS team_name,
    s.raw_json->'participant'->>'short_code'    AS team_short_code,
    s.raw_json->'participant'->>'image_path'    AS team_image_path,
    -- Overall
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 129 THEN (d->>'value')::INTEGER END) AS overall_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 130 THEN (d->>'value')::INTEGER END) AS overall_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 131 THEN (d->>'value')::INTEGER END) AS overall_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 132 THEN (d->>'value')::INTEGER END) AS overall_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 133 THEN (d->>'value')::INTEGER END) AS goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 134 THEN (d->>'value')::INTEGER END) AS goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 179 THEN (d->>'value')::INTEGER END) AS goal_diff,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 187 THEN (d->>'value')::INTEGER END) AS overall_points,
    -- Home
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 135 THEN (d->>'value')::INTEGER END) AS home_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 136 THEN (d->>'value')::INTEGER END) AS home_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 137 THEN (d->>'value')::INTEGER END) AS home_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 138 THEN (d->>'value')::INTEGER END) AS home_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 139 THEN (d->>'value')::INTEGER END) AS home_goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 140 THEN (d->>'value')::INTEGER END) AS home_goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 185 THEN (d->>'value')::INTEGER END) AS home_points,
    -- Away
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 141 THEN (d->>'value')::INTEGER END) AS away_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 142 THEN (d->>'value')::INTEGER END) AS away_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 143 THEN (d->>'value')::INTEGER END) AS away_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 144 THEN (d->>'value')::INTEGER END) AS away_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 145 THEN (d->>'value')::INTEGER END) AS away_goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 146 THEN (d->>'value')::INTEGER END) AS away_goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 186 THEN (d->>'value')::INTEGER END) AS away_points,
    -- Form
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 176 THEN d->>'value' END)            AS streak
FROM {{ source('bronze', 'sportmonks__standings') }} AS s,
unnest(json_transform(s.raw_json::VARCHAR, '{"details": ["JSON"]}').details) AS t(d)
WHERE json_array_length(json_extract(s.raw_json::VARCHAR, '$.details')) > 0
GROUP BY s.id, s.raw_json
