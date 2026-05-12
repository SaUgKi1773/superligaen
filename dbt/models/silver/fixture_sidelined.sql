SELECT
    (sl->>'id')::INTEGER              AS id,
    f.id                              AS fixture_id,
    (sl->>'participant_id')::INTEGER  AS team_id,
    (sl->>'player_id')::INTEGER       AS player_id,
    (sl->>'type_id')::INTEGER         AS type_id
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"sidelined": ["JSON"]}').sidelined) AS t(sl)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.sidelined')) > 0
