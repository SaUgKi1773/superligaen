{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT  1 AS team_side_sk, 'Home'                    AS team_side
UNION ALL SELECT  2, 'Away'
UNION ALL SELECT -1, 'Unknown Team Side'
UNION ALL SELECT -2, 'Not Applicable Team Side'
