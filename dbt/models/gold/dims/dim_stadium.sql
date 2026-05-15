{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='stadium_id',
        merge_update_columns=['stadium_name', 'stadium_address', 'stadium_city', 'stadium_country', 'stadium_capacity', 'stadium_surface', 'stadium_latitude', 'stadium_longitude', 'stadium_image'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE stadium_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Stadium', 'Unknown Stadium Address', 'Unknown Stadium City', 'Unknown Stadium Country', NULL::INTEGER, 'Unknown Stadium Surface', NULL::DOUBLE, NULL::DOUBLE, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Stadium', 'Not Applicable Stadium Address', 'Not Applicable Stadium City', 'Not Applicable Stadium Country', NULL::INTEGER, 'Not Applicable Stadium Surface', NULL::DOUBLE, NULL::DOUBLE, NULL::VARCHAR)) t(stadium_sk, stadium_id, stadium_name, stadium_address, stadium_city, stadium_country, stadium_capacity, stadium_surface, stadium_latitude, stadium_longitude, stadium_image)"
        ]
    )
}}

WITH from_venues AS (
    SELECT DISTINCT ON (id)
        id           AS venue_id,
        name,
        address,
        city_name    AS city,
        country_name AS country,
        surface,
        capacity,
        latitude,
        longitude,
        image_path
    FROM {{ ref('venues') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
from_fixtures AS (
    SELECT DISTINCT
        venue_id,
        venue_name    AS name,
        NULL          AS address,
        venue_city    AS city,
        NULL          AS country,
        venue_surface AS surface,
        venue_capacity AS capacity,
        NULL::DOUBLE  AS latitude,
        NULL::DOUBLE  AS longitude,
        NULL::VARCHAR AS image_path
    FROM {{ ref('fixtures') }}
    WHERE venue_id IS NOT NULL
      AND venue_id NOT IN (SELECT venue_id FROM from_venues)
      AND venue_name IS NOT NULL
),
combined AS (
    SELECT * FROM from_venues
    UNION ALL
    SELECT * FROM from_fixtures
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(stadium_sk), 0) FROM {{ this }} WHERE stadium_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    {% endif %}
    venue_id   AS stadium_id,
    name       AS stadium_name,
    address    AS stadium_address,
    city       AS stadium_city,
    country    AS stadium_country,
    capacity   AS stadium_capacity,
    surface    AS stadium_surface,
    latitude   AS stadium_latitude,
    longitude  AS stadium_longitude,
    image_path AS stadium_image
FROM combined
