{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

-- EAV table: one row per player per stat per fixture. Join with silver.types on type_id for metric name.
WITH lineups AS (
    SELECT
        f.id          AS fixture_id,
        f._ingested_at,
        lu            AS lineup_json
    FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
    unnest(json_transform(f.raw_json::VARCHAR, '{"lineups": ["JSON"]}').lineups) AS t(lu)
    WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.lineups')) > 0
      AND json_array_length(json_extract(lu::VARCHAR, '$.details')) > 0
    {% if is_incremental() %}
    AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
    {% endif %}
)
SELECT
    (d->>'id')::BIGINT             AS id,
    lineups.fixture_id,
    (d->>'player_id')::INTEGER     AS player_id,
    (d->>'team_id')::INTEGER       AS team_id,
    (d->>'lineup_id')::BIGINT      AS lineup_id,
    (d->>'type_id')::INTEGER       AS type_id,
    TRY_CAST(
        CASE d->'data'->>'value'
            WHEN 'true'  THEN '1'
            WHEN 'false' THEN '0'
            ELSE d->'data'->>'value'
        END
    AS DOUBLE) AS value,
    lineups._ingested_at
FROM lineups,
unnest(json_transform(lineup_json::VARCHAR, '{"details": ["JSON"]}').details) AS t(d)
