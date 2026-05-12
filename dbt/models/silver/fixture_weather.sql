SELECT
    (raw_json->'weatherreport'->>'id')::INTEGER                      AS id,
    id                                                                AS fixture_id,
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
    raw_json->'weatherreport'->>'metric'                             AS metric
FROM {{ source('bronze', 'sportmonks__fixtures') }}
WHERE raw_json->'weatherreport' IS NOT NULL
  AND raw_json->'weatherreport' != 'null'::JSON
