SELECT
    id,
    (raw_json->>'country_id')::INTEGER           AS country_id,
    (raw_json->>'nationality_id')::INTEGER       AS nationality_id,
    (raw_json->>'position_id')::INTEGER          AS position_id,
    (raw_json->>'detailed_position_id')::INTEGER AS detailed_position_id,
    raw_json->>'common_name'                     AS common_name,
    raw_json->>'firstname'                       AS firstname,
    raw_json->>'lastname'                        AS lastname,
    raw_json->>'display_name'                    AS display_name,
    raw_json->>'gender'                          AS gender,
    (raw_json->>'date_of_birth')::DATE           AS date_of_birth,
    (raw_json->>'height')::INTEGER               AS height,
    (raw_json->>'weight')::INTEGER               AS weight,
    raw_json->>'image_path'                      AS image_path
FROM {{ source('bronze', 'sportmonks__core_players') }}
