{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'country_id')::INTEGER       AS country_id,
    (raw_json->>'venue_id')::INTEGER         AS venue_id,
    raw_json->>'name'                        AS name,
    raw_json->>'short_code'                  AS short_code,
    raw_json->>'gender'                      AS gender,
    raw_json->>'type'                        AS type,
    (raw_json->>'founded')::INTEGER          AS founded,
    (raw_json->>'placeholder')::BOOLEAN      AS placeholder,
    (raw_json->>'last_played_at')::TIMESTAMP AS last_played_at,
    raw_json->>'image_path'                  AS image_path,
    raw_json->'country'->>'name'             AS country_name,
    raw_json->'venue'->>'name'               AS venue_name,
    raw_json->'venue'->>'city_name'          AS venue_city,
    (raw_json->'venue'->>'capacity')::INTEGER AS venue_capacity,
    _season_id,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__teams') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
