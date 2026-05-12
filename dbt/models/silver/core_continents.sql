SELECT
    id,
    raw_json->>'name' AS name,
    raw_json->>'code' AS code
FROM {{ source('bronze', 'sportmonks__core_continents') }}
