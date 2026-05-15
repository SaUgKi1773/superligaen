{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    raw_json->>'state'          AS state_code,
    raw_json->>'name'           AS name,
    raw_json->>'short_name'     AS short_name,
    raw_json->>'developer_name' AS developer_name,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__states') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
