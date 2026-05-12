SELECT
    id,
    (raw_json->>'model_id')::INTEGER   AS stage_id,
    (raw_json->>'type_id')::INTEGER    AS type_id,
    (raw_json->>'relation_id')::INTEGER AS relation_id,
    raw_json->>'value'                 AS value,
    raw_json->'type'->>'name'         AS stat_name,
    raw_json->'type'->>'code'         AS stat_code,
    raw_json->'type'->>'stat_group'   AS stat_group
FROM {{ source('bronze', 'sportmonks__stage_statistics') }}
