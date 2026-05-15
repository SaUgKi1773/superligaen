{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'sport_id')::INTEGER    AS sport_id,
    (raw_json->>'country_id')::INTEGER  AS country_id,
    raw_json->>'name'                   AS name,
    raw_json->>'short_code'             AS short_code,
    raw_json->>'type'                   AS type,
    raw_json->>'sub_type'               AS sub_type,
    (raw_json->>'active')::BOOLEAN      AS active,
    (raw_json->>'category')::INTEGER    AS category,
    (raw_json->>'has_jerseys')::BOOLEAN AS has_jerseys,
    (raw_json->>'last_played_at')::TIMESTAMP AS last_played_at,
    raw_json->>'image_path'             AS image_path,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__league') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
