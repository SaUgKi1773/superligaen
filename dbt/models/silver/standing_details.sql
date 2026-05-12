SELECT
    s.id                                    AS standing_id,
    (s.raw_json->>'season_id')::INTEGER     AS season_id,
    (s.raw_json->>'stage_id')::INTEGER      AS stage_id,
    (s.raw_json->>'participant_id')::INTEGER AS team_id,
    (detail->>'id')::BIGINT               AS detail_id,
    (detail->>'type_id')::INTEGER         AS type_id,
    (detail->>'value')::DOUBLE            AS value,
    detail->>'standing_type'              AS standing_type
FROM {{ source('bronze', 'sportmonks__standings') }} AS s,
unnest(json_transform(s.raw_json::VARCHAR, '{"details": ["JSON"]}').details) AS t(detail)
WHERE json_array_length(json_extract(s.raw_json::VARCHAR, '$.details')) > 0
