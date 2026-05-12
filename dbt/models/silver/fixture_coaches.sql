{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['coach_id', 'fixture_id']
) }}

-- Match-day coach per team per fixture.
SELECT
    (c->>'id')::INTEGER                     AS coach_id,
    f.id                                    AS fixture_id,
    (c->'meta'->>'participant_id')::INTEGER AS team_id,
    c->>'common_name'                       AS common_name,
    c->>'display_name'                      AS display_name,
    c->>'firstname'                         AS firstname,
    c->>'lastname'                          AS lastname,
    (c->>'country_id')::INTEGER             AS country_id,
    (c->>'nationality_id')::INTEGER         AS nationality_id,
    c->>'image_path'                        AS image_path,
    f._ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"coaches": ["JSON"]}').coaches) AS t(c)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.coaches')) > 0
{% if is_incremental() %}
AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
