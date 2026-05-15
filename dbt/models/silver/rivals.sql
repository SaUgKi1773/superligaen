{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'team_id')::INTEGER  AS team_id,
    (raw_json->>'rival_id')::INTEGER AS rival_id,
    (raw_json->>'sport_id')::INTEGER AS sport_id,
    raw_json->'team'->>'name'        AS team_name,
    raw_json->'team'->>'image_path'  AS team_image_path,
    raw_json->'rival'->>'name'       AS rival_name,
    raw_json->'rival'->>'image_path' AS rival_image_path,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__rivals') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
