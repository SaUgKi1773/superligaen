SELECT
    (score->>'id')::INTEGER            AS id,
    f.id                               AS fixture_id,
    (score->>'type_id')::INTEGER       AS type_id,
    (score->>'participant_id')::INTEGER AS team_id,
    (score->'score'->>'goals')::INTEGER AS goals,
    score->'score'->>'participant'     AS side,
    score->>'description'              AS description
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"scores": ["JSON"]}').scores) AS t(score)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.scores')) > 0
