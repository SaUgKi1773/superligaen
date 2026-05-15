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
    (stat->>'id')::INTEGER              AS id,
    f.id                                AS fixture_id,
    (stat->>'type_id')::INTEGER         AS type_id,
    (stat->>'participant_id')::INTEGER  AS team_id,
    (stat->'data'->>'value')::DOUBLE    AS value,
    stat->>'location'                   AS location,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"statistics": ["JSON"]}').statistics) AS t(stat)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.statistics')) > 0
