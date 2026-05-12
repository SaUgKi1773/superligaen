{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='referee_name',
        merge_update_columns=['referee_name'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, 'Unknown Referee'), (-2, 'Not Applicable Referee')) t(referee_sk, referee_name) WHERE t.referee_sk NOT IN (SELECT referee_sk FROM {{ this }})"
        ]
    )
}}

WITH distinct_referees AS (
    SELECT DISTINCT referee AS referee_name
    FROM {{ ref('fixtures') }}
    WHERE referee IS NOT NULL AND referee <> ''
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {{ this }} WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.referee_name) AS referee_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.referee_name) AS referee_sk,
    {% endif %}
    src.referee_name
FROM distinct_referees src
