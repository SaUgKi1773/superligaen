{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    (fm->>'id')::INTEGER             AS id,
    f.id                             AS fixture_id,
    (fm->>'participant_id')::INTEGER AS team_id,
    fm->>'formation'                 AS formation,
    fm->>'location'                  AS location,
    f._ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"formations": ["JSON"]}').formations) AS t(fm)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.formations')) > 0
{% if is_incremental() %}
AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
