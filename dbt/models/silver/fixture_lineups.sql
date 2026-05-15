{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    (lu->>'id')::BIGINT               AS id,
    f.id                              AS fixture_id,
    (lu->>'player_id')::INTEGER       AS player_id,
    (lu->>'team_id')::INTEGER         AS team_id,
    (lu->>'position_id')::INTEGER     AS position_id,
    (lu->>'type_id')::INTEGER         AS type_id,
    lu->>'player_name'                AS player_name,
    (lu->>'jersey_number')::INTEGER   AS jersey_number,
    lu->>'formation_field'            AS formation_field,
    (lu->>'formation_position')::INTEGER AS formation_position,
    lu->'type'->>'name'                  AS type_name,
    lu->'position'->>'name'              AS position_name,
    lu->'position'->>'code'              AS position_code,
    lu->'detailedposition'->>'name'      AS detailed_position_name,
    f._ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"lineups": ["JSON"]}').lineups) AS t(lu)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.lineups')) > 0
{% if is_incremental() %}
AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
