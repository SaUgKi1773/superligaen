{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'country_id')::INTEGER  AS country_id,
    (raw_json->>'city_id')::INTEGER     AS city_id,
    raw_json->>'common_name'            AS common_name,
    raw_json->>'firstname'              AS firstname,
    raw_json->>'lastname'               AS lastname,
    raw_json->>'display_name'           AS display_name,
    raw_json->>'gender'                 AS gender,
    (raw_json->>'height')::INTEGER      AS height,
    (raw_json->>'weight')::INTEGER      AS weight,
    (raw_json->>'date_of_birth')::DATE  AS date_of_birth,
    raw_json->'country'->>'name'        AS country_name,
    raw_json->'country'->>'iso2'        AS country_iso2,
    raw_json->'country'->>'fifa_name'   AS country_fifa_name,
    raw_json->>'image_path'             AS image_path,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__referees') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
