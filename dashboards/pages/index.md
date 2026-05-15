---
sidebar: never
hide_toc: true
title: " "
---

```sql league
select * from superligaen.league_info
```

```sql last_updated
select * from superligaen.last_updated
```

```sql kpis
select
    count(distinct match_id)    as total_matches,
    sum(goals_scored)           as total_goals,
    count(distinct team_name)   as total_teams,
    max(season)                 as season
from superligaen.mart_match_facts
where is_current_season = true
  and result in ('Win', 'Draw', 'Loss')
```

```sql leader
select team_name, team_short_name, pts
from (
    select
        team_name,
        team_short_name,
        standings_type,
        sum(points_earned)                      as pts,
        sum(goals_scored) - sum(goals_conceded) as gd,
        sum(goals_scored)                       as gf
    from superligaen.mart_match_facts
    where is_current_season = true
      and result in ('Win', 'Draw', 'Loss')
    group by team_name, team_short_name, standings_type
)
order by
    case standings_type
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        when 'Regular Season'     then 3
    end,
    pts desc, gd desc, gf desc
limit 1
```

<div class="relative rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-10 mb-6 shadow-xl">
  <div class="absolute top-4 right-4 bg-white/10 rounded-xl p-2 backdrop-blur">
    <img src="{league[0].league_logo}" alt="Superligaen" class="h-8 md:h-12" />
  </div>
  <div class="flex items-center justify-center gap-4 md:gap-6">
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-7 md:h-10 rounded-lg shadow-lg opacity-90" />
    <div class="text-center">
      <div class="text-3xl md:text-5xl font-extrabold tracking-tight text-white">Superligaen</div>
      <div class="text-gray-400 text-xs md:text-sm mt-2 md:mt-3 uppercase tracking-widest">Danish Premier Football League</div>
      <div class="inline-block mt-2 px-3 py-1 rounded-full bg-blue-500/20 border border-blue-400/30 text-blue-300 text-sm font-semibold">
        Current Season: {kpis[0].season}
      </div>
    </div>
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-7 md:h-10 rounded-lg shadow-lg opacity-90" />
  </div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={leader}  value=team_short_name  title="Current Leader"  /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}    value=total_teams    title="Teams"           /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}    value=total_matches  title="Matches Played"  /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}    value=total_goals    title="Goals Scored"    /></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4">

<a href="/standings" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">🏆</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Standings</div>
      <div class="text-gray-400 text-sm mt-1">Championship, Relegation &amp; Regular Season tables</div>
    </div>
  </div>
</a>

<a href="/match-results" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">⚽</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Match Results</div>
      <div class="text-gray-400 text-sm mt-1">Full match history, scorelines and analytics by round</div>
    </div>
  </div>
</a>

<a href="/upcoming-matches" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">📅</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Upcoming Fixtures</div>
      <div class="text-gray-400 text-sm mt-1">Head-to-head history &amp; form guide for upcoming matches</div>
    </div>
  </div>
</a>

<a href="/league-analytics" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">🌍</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">League Analysis</div>
      <div class="text-gray-400 text-sm mt-1">Cross-team benchmarks, rankings and league-wide trends</div>
    </div>
  </div>
</a>

<a href="/team-analytics" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">📊</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Team Analysis</div>
      <div class="text-gray-400 text-sm mt-1">Deep-dive KPIs, form, shooting accuracy &amp; discipline</div>
    </div>
  </div>
</a>

<a href="/referee-analytics" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">🟨</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Referee Analysis</div>
      <div class="text-gray-400 text-sm mt-1">Cards, fouls, team exposure and match logs by referee</div>
    </div>
  </div>
</a>

<a href="/glossary" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">📖</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Data Glossary</div>
      <div class="text-gray-400 text-sm mt-1">Definitions and formulas for all KPIs and abbreviations</div>
    </div>
  </div>
</a>

<a href="/about" class="block no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm">
  <div class="flex items-start gap-4">
    <div class="text-3xl">👤</div>
    <div>
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">About This Project</div>
      <div class="text-gray-400 text-sm mt-1">The story behind this project, the blog &amp; the author</div>
    </div>
  </div>
</a>

</div>

<div class="mt-8 text-center text-xs text-gray-400">Data last updated: {last_updated[0]?.last_updated}</div>
