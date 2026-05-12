SELECT
    (stat->>'id')::INTEGER             AS id,
    f.id                               AS fixture_id,
    (stat->>'type_id')::INTEGER        AS type_id,
    (stat->>'participant_id')::INTEGER AS team_id,
    stat->'data'->>'value'             AS value,
    stat->>'location'                  AS location
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"statistics": ["JSON"]}').statistics) AS t(stat)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.statistics')) > 0
