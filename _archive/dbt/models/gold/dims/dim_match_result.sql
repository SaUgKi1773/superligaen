{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT  1 AS match_result_sk, 'Win'                         AS match_result
UNION ALL SELECT  2, 'Draw'
UNION ALL SELECT  3, 'Loss'
UNION ALL SELECT  4, 'Pending'
UNION ALL SELECT -1, 'Unknown Match Result'
UNION ALL SELECT -2, 'Not Applicable Match Result'
