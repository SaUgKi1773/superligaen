{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    (event->>'id')::INTEGER              AS id,
    f.id                                 AS fixture_id,
    (event->>'period_id')::INTEGER       AS period_id,
    (event->>'participant_id')::INTEGER  AS team_id,
    (event->>'type_id')::INTEGER         AS type_id,
    (event->>'player_id')::INTEGER       AS player_id,
    (event->>'related_player_id')::INTEGER AS related_player_id,
    event->>'player_name'                AS player_name,
    event->>'related_player_name'        AS related_player_name,
    event->>'section'                    AS section,
    event->>'result'                     AS result,
    event->>'info'                       AS info,
    event->>'addition'                   AS addition,
    (event->>'minute')::INTEGER          AS minute,
    (event->>'extra_minute')::INTEGER    AS extra_minute,
    (event->>'injured')::BOOLEAN         AS injured,
    (event->>'on_bench')::BOOLEAN        AS on_bench,
    (event->>'sub_type_id')::INTEGER     AS sub_type_id,
    (event->>'sort_order')::INTEGER      AS sort_order,
    (event->>'rescinded')::BOOLEAN       AS rescinded,
    f._ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"events": ["JSON"]}').events) AS t(event)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.events')) > 0
{% if is_incremental() %}
AND f._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
