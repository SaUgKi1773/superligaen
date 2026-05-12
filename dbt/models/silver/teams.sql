SELECT
    id,
    (raw_json->>'country_id')::INTEGER AS country_id,
    (raw_json->>'venue_id')::INTEGER   AS venue_id,
    raw_json->>'name'                  AS name,
    raw_json->>'short_code'            AS short_code,
    raw_json->>'gender'                AS gender,
    raw_json->>'type'                  AS type,
    (raw_json->>'founded')::INTEGER    AS founded,
    (raw_json->>'placeholder')::BOOLEAN AS placeholder,
    (raw_json->>'last_played_at')::TIMESTAMP AS last_played_at,
    raw_json->>'image_path'            AS image_path
FROM {{ source('bronze', 'sportmonks__teams') }}
