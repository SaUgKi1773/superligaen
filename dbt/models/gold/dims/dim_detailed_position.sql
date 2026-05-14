{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='detailed_position_name',
        merge_update_columns=['detailed_position_name'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, 'Unknown')) t(detailed_position_sk, detailed_position_name) WHERE t.detailed_position_sk NOT IN (SELECT detailed_position_sk FROM {{ this }})"
        ]
    )
}}

WITH detailed_positions AS (
    SELECT DISTINCT detailed_position_name
    FROM {{ ref('fixture_lineups') }}
    WHERE detailed_position_name IS NOT NULL
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(detailed_position_sk), 0) FROM {{ this }} WHERE detailed_position_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY detailed_position_name) AS detailed_position_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY detailed_position_name) AS detailed_position_sk,
    {% endif %}
    detailed_position_name
FROM detailed_positions
