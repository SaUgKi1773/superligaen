{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='fixture_id'
) }}

SELECT
    id                                                                AS fixture_id,
    (raw_json->'weatherreport'->>'id')::INTEGER                      AS id,
    (raw_json->'weatherreport'->>'venue_id')::INTEGER                AS venue_id,
    (raw_json->'weatherreport'->'temperature'->>'day')::DOUBLE       AS temp_day,
    (raw_json->'weatherreport'->'current'->>'temp')::DOUBLE          AS temp_current,
    (raw_json->'weatherreport'->'current'->>'feels_like')::DOUBLE    AS feels_like,
    (raw_json->'weatherreport'->'wind'->>'speed')::DOUBLE            AS wind_speed,
    (raw_json->'weatherreport'->'wind'->>'direction')::INTEGER       AS wind_direction,
    raw_json->'weatherreport'->>'humidity'                           AS humidity,
    (raw_json->'weatherreport'->>'pressure')::INTEGER                AS pressure,
    raw_json->'weatherreport'->>'clouds'                             AS clouds,
    raw_json->'weatherreport'->>'description'                        AS description,
    raw_json->'weatherreport'->>'metric'                             AS metric,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }}
WHERE json_extract(raw_json::VARCHAR, '$.weatherreport') IS NOT NULL
{% if is_incremental() %}
AND _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
