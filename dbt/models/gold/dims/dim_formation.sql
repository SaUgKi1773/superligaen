{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='formation',
        merge_update_columns=['formation'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, 'Unknown'), (-2, 'Not Applicable')) t(formation_sk, formation) WHERE t.formation_sk NOT IN (SELECT formation_sk FROM {{ this }})"
        ]
    )
}}

WITH formations AS (
    SELECT DISTINCT formation
    FROM {{ ref('fixture_formations') }}
    WHERE formation IS NOT NULL
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(formation_sk), 0) FROM {{ this }} WHERE formation_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY formation) AS formation_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY formation) AS formation_sk,
    {% endif %}
    formation
FROM formations
