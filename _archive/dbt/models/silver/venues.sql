{{
    config(
        materialized='table'
    )
}}

SELECT
    league_id,
    (elem->>'$.id')::INTEGER       AS venue_id,
    elem->>'$.name'                AS venue_name,
    elem->>'$.address'             AS address,
    elem->>'$.city'                AS city,
    elem->>'$.country'             AS country,
    (elem->>'$.capacity')::INTEGER AS capacity,
    elem->>'$.surface'             AS surface,
    elem->>'$.image'               AS image,
    ingested_at
FROM {{ source('bronze', 'api_football__venues') }},
UNNEST(raw_json::JSON[]) AS t(elem)
