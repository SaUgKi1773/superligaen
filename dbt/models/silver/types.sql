{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    raw_json->>'name'           AS name,
    raw_json->>'code'           AS code,
    raw_json->>'developer_name' AS developer_name,
    raw_json->>'model_type'     AS model_type,
    raw_json->>'stat_group'     AS stat_group,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__types') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
