{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT  1 AS appearance_type_sk, 'Starter'                        AS appearance_type
UNION ALL SELECT  2, 'Substitute'
UNION ALL SELECT -1, 'Unknown Appearance Type'
UNION ALL SELECT -2, 'Not Applicable Appearance Type'
