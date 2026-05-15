{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'league_id')::INTEGER            AS league_id,
    (raw_json->>'season_id')::INTEGER            AS season_id,
    (raw_json->>'type_id')::INTEGER              AS type_id,
    (raw_json->>'tie_breaker_rule_id')::INTEGER  AS tie_breaker_rule_id,
    raw_json->>'name'                            AS name,
    (raw_json->>'sort_order')::INTEGER           AS sort_order,
    (raw_json->>'finished')::BOOLEAN             AS finished,
    (raw_json->>'is_current')::BOOLEAN           AS is_current,
    (raw_json->>'starting_at')::DATE             AS starting_at,
    (raw_json->>'ending_at')::DATE               AS ending_at,
    (raw_json->>'games_in_current_week')::BOOLEAN AS games_in_current_week,
    raw_json->'type'->>'name'                    AS type_name,
    raw_json->'type'->>'developer_name'          AS type_developer_name,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__stages') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
