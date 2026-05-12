SELECT
    (period->>'id')::INTEGER           AS id,
    f.id                               AS fixture_id,
    (period->>'type_id')::INTEGER      AS type_id,
    period->>'description'             AS description,
    (period->>'sort_order')::INTEGER   AS sort_order,
    (period->>'started')::BIGINT       AS started_timestamp,
    (period->>'ended')::BIGINT         AS ended_timestamp,
    (period->>'counts_from')::INTEGER  AS counts_from,
    (period->>'period_length')::INTEGER AS period_length,
    (period->>'time_added')::INTEGER   AS time_added,
    (period->>'minutes')::INTEGER      AS minutes,
    (period->>'seconds')::INTEGER      AS seconds,
    (period->>'ticking')::BOOLEAN      AS ticking,
    (period->>'has_timer')::BOOLEAN    AS has_timer
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"periods": ["JSON"]}').periods) AS t(period)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.periods')) > 0
