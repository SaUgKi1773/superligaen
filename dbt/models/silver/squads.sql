{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'player_id')::INTEGER           AS player_id,
    (raw_json->>'team_id')::INTEGER             AS team_id,
    (raw_json->>'season_id')::INTEGER           AS season_id,
    (raw_json->>'position_id')::INTEGER         AS position_id,
    (raw_json->>'jersey_number')::INTEGER       AS jersey_number,
    (raw_json->>'has_values')::BOOLEAN          AS has_values,
    raw_json->'player'->>'common_name'          AS player_common_name,
    raw_json->'player'->>'display_name'         AS player_display_name,
    raw_json->'player'->>'firstname'            AS player_firstname,
    raw_json->'player'->>'lastname'             AS player_lastname,
    raw_json->'player'->>'gender'               AS player_gender,
    (raw_json->'player'->>'country_id')::INTEGER     AS player_country_id,
    (raw_json->'player'->>'nationality_id')::INTEGER AS player_nationality_id,
    (raw_json->'player'->>'height')::INTEGER         AS player_height,
    (raw_json->'player'->>'weight')::INTEGER         AS player_weight,
    (raw_json->'player'->>'date_of_birth')::DATE     AS player_date_of_birth,
    raw_json->'player'->>'image_path'                AS player_image_path,
    raw_json->'position'->>'name'               AS position_name,
    raw_json->'position'->>'code'               AS position_code,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__squads') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
