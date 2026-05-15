{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='stadium_id',
        merge_update_columns=['stadium_name', 'stadium_address', 'stadium_city', 'stadium_country', 'stadium_capacity', 'stadium_surface'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Stadium Name', 'Unknown Stadium Address', 'Unknown Stadium City', 'Unknown Stadium Country', NULL::INTEGER, 'Unknown Stadium Surface'), (-2, NULL::INTEGER, 'Not Applicable Stadium Name', 'Not Applicable Stadium Address', 'Not Applicable Stadium City', 'Not Applicable Stadium Country', NULL::INTEGER, 'Not Applicable Stadium Surface')) t(stadium_sk, stadium_id, stadium_name, stadium_address, stadium_city, stadium_country, stadium_capacity, stadium_surface) WHERE t.stadium_sk NOT IN (SELECT stadium_sk FROM {{ this }})"
        ]
    )
}}

WITH venues_from_api AS (
    SELECT
        venue_id,
        venue_name,
        address,
        city,
        country,
        capacity,
        surface
    FROM {{ ref('venues') }}
    WHERE venue_id IS NOT NULL
),
venues_from_fixtures AS (
    SELECT DISTINCT
        f.venue_id,
        f.venue_name,
        f.venue_city                     AS city,
        'Unknown Stadium Address'        AS address,
        'Unknown Stadium Country'        AS country,
        NULL::INTEGER                    AS capacity,
        'Unknown Stadium Surface'        AS surface
    FROM {{ ref('fixtures') }} f
    LEFT JOIN venues_from_api v ON v.venue_id = f.venue_id
    WHERE f.venue_id IS NOT NULL
      AND v.venue_id IS NULL
),
combined AS (
    SELECT * FROM venues_from_api
    UNION ALL
    SELECT * FROM venues_from_fixtures
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(stadium_sk), 0) FROM {{ this }} WHERE stadium_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    {% endif %}
    venue_id    AS stadium_id,
    venue_name  AS stadium_name,
    address     AS stadium_address,
    city        AS stadium_city,
    country     AS stadium_country,
    capacity    AS stadium_capacity,
    surface     AS stadium_surface
FROM combined
