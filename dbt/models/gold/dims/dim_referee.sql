{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='referee_id',
        merge_update_columns=['referee_common_name', 'referee_firstname', 'referee_lastname', 'referee_display_name', 'referee_nationality', 'referee_image_path'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Referee', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Referee', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(referee_sk, referee_id, referee_common_name, referee_firstname, referee_lastname, referee_display_name, referee_nationality, referee_image_path) WHERE t.referee_sk NOT IN (SELECT referee_sk FROM {{ this }})"
        ]
    )
}}

WITH from_referees AS (
    SELECT DISTINCT ON (id)
        id           AS referee_id,
        common_name  AS referee_common_name,
        firstname    AS referee_firstname,
        lastname     AS referee_lastname,
        display_name AS referee_display_name,
        country_name AS referee_nationality,
        image_path   AS referee_image_path
    FROM {{ ref('referees') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
from_fixtures AS (
    SELECT DISTINCT ON (referee_id)
        referee_id,
        referee_common_name,
        referee_firstname,
        referee_lastname,
        referee_display_name,
        NULL::VARCHAR AS referee_nationality,
        referee_image_path
    FROM {{ ref('fixture_referees') }}
    WHERE referee_id IS NOT NULL
      AND referee_id NOT IN (SELECT referee_id FROM from_referees)
    ORDER BY referee_id, _ingested_at DESC
),
combined AS (
    SELECT * FROM from_referees
    UNION ALL
    SELECT * FROM from_fixtures
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {{ this }} WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY referee_id) AS referee_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY referee_id) AS referee_sk,
    {% endif %}
    referee_id,
    referee_common_name,
    referee_firstname,
    referee_lastname,
    referee_display_name,
    referee_nationality,
    referee_image_path
FROM combined
