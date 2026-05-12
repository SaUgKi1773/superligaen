{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'country_id')::INTEGER    AS country_id,
    (raw_json->>'city_id')::INTEGER       AS city_id,
    raw_json->>'name'                     AS name,
    raw_json->>'address'                  AS address,
    raw_json->>'zipcode'                  AS zipcode,
    raw_json->>'city_name'                AS city_name,
    raw_json->>'surface'                  AS surface,
    (raw_json->>'capacity')::INTEGER      AS capacity,
    (raw_json->>'latitude')::DOUBLE       AS latitude,
    (raw_json->>'longitude')::DOUBLE      AS longitude,
    (raw_json->>'national_team')::BOOLEAN AS national_team,
    raw_json->>'image_path'               AS image_path,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__venues') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
