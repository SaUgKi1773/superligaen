SELECT
    id,
    (raw_json->>'country_id')::INTEGER AS country_id,
    raw_json->>'name'                  AS name
FROM {{ source('bronze', 'sportmonks__core_regions') }}
