SELECT
    id,
    raw_json->>'name'           AS name,
    raw_json->>'code'           AS code,
    raw_json->>'developer_name' AS developer_name,
    raw_json->>'model_type'     AS model_type,
    raw_json->>'stat_group'     AS stat_group
FROM {{ source('bronze', 'sportmonks__types') }}
