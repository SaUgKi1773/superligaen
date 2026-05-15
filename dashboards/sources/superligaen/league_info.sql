select
    league_name,
    league_logo,
    league_country_flag
from superligaen.gold.dim_league
where league_id = 271
limit 1
