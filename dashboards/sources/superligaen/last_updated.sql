select strftime(max(_ingested_at), '%d %b %Y %H:%M UTC') as last_updated
from superligaen.bronze.sportmonks__fixtures
