-- EAV table: one row per player per stat per fixture. Join with silver.types on type_id for metric name.
WITH lineups AS (
    SELECT
        f.id AS fixture_id,
        lu   AS lineup_json
    FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
    unnest(json_transform(f.raw_json::VARCHAR, '{"lineups": ["JSON"]}').lineups) AS t(lu)
    WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.lineups')) > 0
      AND json_array_length(json_extract(lu::VARCHAR, '$.details')) > 0
)
SELECT
    (d->>'id')::BIGINT            AS id,
    lineups.fixture_id,
    (d->>'player_id')::INTEGER    AS player_id,
    (d->>'team_id')::INTEGER      AS team_id,
    (d->>'lineup_id')::BIGINT     AS lineup_id,
    (d->>'type_id')::INTEGER      AS type_id,
    (d->'data'->>'value')::DOUBLE AS value
FROM lineups,
unnest(json_transform(lineup_json::VARCHAR, '{"details": ["JSON"]}').details) AS t(d)
