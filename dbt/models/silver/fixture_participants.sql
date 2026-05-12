{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', 'team_id']
) }}

SELECT
    f.id                                       AS fixture_id,
    (participant->>'id')::INTEGER              AS team_id,
    participant->>'name'                       AS team_name,
    participant->>'short_code'                 AS team_short_code,
    participant->>'image_path'                 AS team_image_path,
    participant->'meta'->>'location'           AS location,
    (participant->'meta'->>'winner')::BOOLEAN  AS winner,
    (participant->'meta'->>'position')::INTEGER AS position,
    f._ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"participants": ["JSON"]}').participants) AS t(participant)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.participants')) > 0
{% if is_incremental() %}
AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
