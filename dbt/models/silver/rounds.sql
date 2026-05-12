{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'league_id')::INTEGER            AS league_id,
    (raw_json->>'season_id')::INTEGER            AS season_id,
    (raw_json->>'stage_id')::INTEGER             AS stage_id,
    raw_json->>'name'                            AS name,
    (raw_json->>'finished')::BOOLEAN             AS finished,
    (raw_json->>'is_current')::BOOLEAN           AS is_current,
    (raw_json->>'starting_at')::DATE             AS starting_at,
    (raw_json->>'ending_at')::DATE               AS ending_at,
    (raw_json->>'games_in_current_week')::BOOLEAN AS games_in_current_week,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__rounds') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
