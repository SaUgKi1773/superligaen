-- Timeline events: shots on target (569), shots off target (570), corners (126), offsides (1514) by minute.
-- Structurally identical to events but a different set of type_ids.
SELECT
    (tl->>'id')::INTEGER              AS id,
    f.id                              AS fixture_id,
    (tl->>'period_id')::INTEGER       AS period_id,
    (tl->>'participant_id')::INTEGER  AS team_id,
    (tl->>'type_id')::INTEGER         AS type_id,
    (tl->>'player_id')::INTEGER       AS player_id,
    tl->>'addition'                   AS addition,
    (tl->>'minute')::INTEGER          AS minute,
    (tl->>'extra_minute')::INTEGER    AS extra_minute,
    (tl->>'sort_order')::INTEGER      AS sort_order
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"timeline": ["JSON"]}').timeline) AS t(tl)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.timeline')) > 0
