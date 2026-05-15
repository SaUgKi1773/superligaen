{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['season', 'league_id', 'team_id']
    )
}}

SELECT
    season,
    league_id,
    (elem->>'$.team.id')::INTEGER          AS team_id,
    elem->>'$.team.name'                   AS team_name,
    elem->>'$.team.code'                   AS team_code,
    elem->>'$.team.country'                AS team_country,
    (elem->>'$.team.founded')::INTEGER     AS team_founded,
    (elem->>'$.team.national')::BOOLEAN    AS team_national,
    elem->>'$.team.logo'                   AS team_logo,
    (elem->>'$.venue.id')::INTEGER         AS venue_id,
    elem->>'$.venue.name'                  AS venue_name,
    elem->>'$.venue.address'               AS venue_address,
    elem->>'$.venue.city'                  AS venue_city,
    (elem->>'$.venue.capacity')::INTEGER   AS venue_capacity,
    elem->>'$.venue.surface'               AS venue_surface,
    elem->>'$.venue.image'                 AS venue_image,
    ingested_at
FROM {{ source('bronze', 'api_football__teams') }},
UNNEST(raw_json::JSON[]) AS t(elem)
{% if is_incremental() %}
WHERE {{ season_filter() }}
{% endif %}
