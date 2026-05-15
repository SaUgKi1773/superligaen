{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

WITH src AS MATERIALIZED (
    SELECT *
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    {% if is_incremental() %}
    WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
    {% endif %}
)

SELECT
    (fm->>'id')::INTEGER             AS id,
    f.id                             AS fixture_id,
    (fm->>'participant_id')::INTEGER AS team_id,
    fm->>'formation'                 AS formation,
    fm->>'location'                  AS location,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"formations": ["JSON"]}').formations) AS t(fm)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.formations')) > 0
