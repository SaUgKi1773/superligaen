{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'model_id')::INTEGER    AS round_id,
    (raw_json->>'type_id')::INTEGER     AS type_id,
    (raw_json->>'relation_id')::INTEGER AS relation_id,
    raw_json->>'value'                  AS value,
    raw_json->'type'->>'name'          AS stat_name,
    raw_json->'type'->>'code'          AS stat_code,
    raw_json->'type'->>'stat_group'    AS stat_group,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__round_statistics') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
