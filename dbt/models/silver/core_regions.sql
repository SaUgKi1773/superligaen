{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'country_id')::INTEGER AS country_id,
    raw_json->>'name'                  AS name,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__core_regions') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
