{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'season_id')::INTEGER      AS season_id,
    (raw_json->>'player_id')::INTEGER      AS player_id,
    (raw_json->>'type_id')::INTEGER        AS type_id,
    (raw_json->>'participant_id')::INTEGER AS team_id,
    (raw_json->>'position')::INTEGER       AS position,
    (raw_json->>'total')::INTEGER          AS total,
    raw_json->'player'->>'common_name'     AS player_common_name,
    raw_json->'player'->>'display_name'    AS player_display_name,
    raw_json->'player'->>'image_path'      AS player_image_path,
    raw_json->'participant'->>'name'       AS team_name,
    raw_json->'type'->>'name'             AS stat_name,
    raw_json->'type'->>'code'             AS stat_code,
    raw_json->'season'->>'name'           AS season_name,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__topscorers') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
