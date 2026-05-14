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

WITH latest AS (
    SELECT DISTINCT ON (id)
        id, common_name, firstname, lastname, display_name, country_name, image_path
    FROM {{ ref('referees') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
with_canonical AS (
    SELECT
        COALESCE(o.canonical_referee_id, l.id) AS canonical_id,
        l.id,
        l.common_name,
        l.firstname,
        l.lastname,
        l.display_name,
        l.country_name,
        l.image_path
    FROM latest l
    LEFT JOIN {{ ref('referee_id_overrides') }} o ON o.referee_id = l.id
),
deduped AS (
    SELECT DISTINCT ON (canonical_id)
        canonical_id,
        common_name,
        firstname,
        lastname,
        display_name,
        country_name,
        image_path
    FROM with_canonical
    ORDER BY
        canonical_id,
        CASE WHEN id = canonical_id THEN 0 ELSE 1 END,
        id
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {{ this }} WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY canonical_id) AS referee_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY canonical_id) AS referee_sk,
    {% endif %}
    canonical_id  AS referee_id,
    common_name   AS referee_common_name,
    firstname     AS referee_firstname,
    lastname      AS referee_lastname,
    display_name  AS referee_display_name,
    country_name  AS referee_nationality,
    image_path    AS referee_image_path
FROM deduped
