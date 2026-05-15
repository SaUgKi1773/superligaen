{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'sport_id')::INTEGER             AS sport_id,
    (raw_json->>'country_id')::INTEGER           AS country_id,
    (raw_json->>'nationality_id')::INTEGER       AS nationality_id,
    (raw_json->>'city_id')::INTEGER              AS city_id,
    (raw_json->>'position_id')::INTEGER          AS position_id,
    (raw_json->>'detailed_position_id')::INTEGER AS detailed_position_id,
    (raw_json->>'type_id')::INTEGER              AS type_id,
    raw_json->>'common_name'                     AS common_name,
    raw_json->>'firstname'                       AS firstname,
    raw_json->>'lastname'                        AS lastname,
    raw_json->>'name'                            AS name,
    raw_json->>'display_name'                    AS display_name,
    raw_json->>'gender'                          AS gender,
    (raw_json->>'date_of_birth')::DATE           AS date_of_birth,
    (raw_json->>'height')::INTEGER               AS height,
    (raw_json->>'weight')::INTEGER               AS weight,
    raw_json->>'image_path'                      AS image_path,
    raw_json->'country'->>'name'                 AS country_name,
    raw_json->'country'->>'iso2'                 AS country_iso2,
    raw_json->'nationality'->>'name'             AS nationality_name,
    raw_json->'city'->>'name'                    AS city_name,
    raw_json->'position'->>'name'                AS position_name,
    raw_json->'position'->>'code'                AS position_code,
    raw_json->'position'->>'developer_name'      AS position_developer_name,
    raw_json->'detailedposition'->>'name'        AS detailed_position_name,
    raw_json->'detailedposition'->>'code'        AS detailed_position_code,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__players') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
