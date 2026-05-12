{{
    config(
        materialized='table'
    )
}}

SELECT
    (elem->>'$.league.id')::INTEGER  AS league_id,
    elem->>'$.league.name'           AS league_name,
    elem->>'$.league.type'           AS league_type,
    elem->>'$.league.logo'           AS league_logo,
    elem->>'$.country.name'          AS country_name,
    elem->>'$.country.code'          AS country_code,
    elem->>'$.country.flag'          AS country_flag,
    (elem->'$.seasons')              AS seasons,
    ingested_at
FROM {{ source('bronze', 'api_football__leagues') }},
UNNEST(raw_json::JSON[]) AS t(elem)
