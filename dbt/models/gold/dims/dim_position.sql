{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='position_name',
        merge_update_columns=['position_short_code', 'position_group', 'position_group_code'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, 'Unknown', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(position_sk, position_name, position_short_code, position_group, position_group_code) WHERE t.position_sk NOT IN (SELECT position_sk FROM {{ this }})"
        ]
    )
}}

WITH position_counts AS (
    SELECT
        detailed_position_name,
        position_name,
        position_code,
        COUNT(*) AS n
    FROM {{ ref('fixture_lineups') }}
    WHERE detailed_position_name IS NOT NULL AND position_name IS NOT NULL
    GROUP BY 1, 2, 3
),
dominant AS (
    SELECT DISTINCT ON (detailed_position_name)
        detailed_position_name,
        position_name   AS position_group,
        position_code   AS position_group_code
    FROM position_counts
    ORDER BY detailed_position_name, n DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(position_sk), 0) FROM {{ this }} WHERE position_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY detailed_position_name) AS position_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY detailed_position_name) AS position_sk,
    {% endif %}
    detailed_position_name AS position_name,
    CASE detailed_position_name
        WHEN 'Goalkeeper'         THEN 'GK'
        WHEN 'Centre Back'        THEN 'CB'
        WHEN 'Left Back'          THEN 'LB'
        WHEN 'Right Back'         THEN 'RB'
        WHEN 'Defensive Midfield' THEN 'DM'
        WHEN 'Central Midfield'   THEN 'CM'
        WHEN 'Attacking Midfield' THEN 'AM'
        WHEN 'Left Midfield'      THEN 'LM'
        WHEN 'Right Midfield'     THEN 'RM'
        WHEN 'Left Wing'          THEN 'LW'
        WHEN 'Right Wing'         THEN 'RW'
        WHEN 'Attacker'           THEN 'ST'
    END                    AS position_short_code,
    position_group,
    position_group_code
FROM dominant
