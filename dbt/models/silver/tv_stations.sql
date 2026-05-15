{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    raw_json->>'name'                  AS name,
    raw_json->>'url'                   AS url,
    raw_json->>'image_path'            AS image_path,
    raw_json->>'type'                  AS type,
    (raw_json->>'related_id')::INTEGER AS related_id,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__tv_stations') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
