{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='league_id',
        merge_update_columns=['league_name', 'league_type', 'league_logo', 'league_country', 'league_country_code', 'league_country_flag'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown League Name', 'Unknown League Type', NULL::VARCHAR, 'Unknown League Country', 'Unknown League Country Code', NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable League Name', 'Not Applicable League Type', NULL::VARCHAR, 'Not Applicable League Country', 'Not Applicable League Country Code', NULL::VARCHAR)) t(league_sk, league_id, league_name, league_type, league_logo, league_country, league_country_code, league_country_flag) WHERE t.league_sk NOT IN (SELECT league_sk FROM {{ this }})"
        ]
    )
}}

SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(league_sk), 0) FROM {{ this }} WHERE league_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.league_id) AS league_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.league_id) AS league_sk,
    {% endif %}
    src.league_id,
    src.league_name,
    src.league_type,
    src.league_logo,
    src.country_name AS league_country,
    src.country_code AS league_country_code,
    src.country_flag AS league_country_flag
FROM {{ ref('leagues') }} src
WHERE src.league_id IS NOT NULL
