SELECT
    (coach->>'id')::INTEGER         AS id,
    t2.id                           AS team_id,
    (coach->>'coach_id')::INTEGER   AS coach_id,
    (coach->>'position_id')::INTEGER AS position_id,
    (coach->>'active')::BOOLEAN     AS active,
    (coach->>'temporary')::BOOLEAN  AS temporary,
    (coach->>'start')::DATE         AS start_date,
    (coach->>'end')::DATE           AS end_date
FROM {{ source('bronze', 'sportmonks__teams') }} AS t2,
unnest(json_transform(t2.raw_json::VARCHAR, '{"coaches": ["JSON"]}').coaches) AS t(coach)
WHERE json_array_length(json_extract(t2.raw_json::VARCHAR, '$.coaches')) > 0
