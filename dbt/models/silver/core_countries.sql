SELECT
    id,
    (raw_json->>'continent_id')::INTEGER AS continent_id,
    raw_json->>'name'                    AS name,
    raw_json->>'official_name'           AS official_name,
    raw_json->>'fifa_name'               AS fifa_name,
    raw_json->>'iso2'                    AS iso2,
    raw_json->>'iso3'                    AS iso3,
    raw_json->>'image_path'             AS flag_image_path
FROM {{ source('bronze', 'sportmonks__core_countries') }}
