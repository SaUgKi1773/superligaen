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
  <div class="rounded-xl border border-gray-200 bg-gray-50 p-4 text-center"><BigValue data={leader}  value=team_short_name  title="Current Leader"  /></div>
  <div class="rounded-xl border border-gray-200 bg-gray-50 p-4 text-center"><BigValue data={kpis}    value=total_teams    title="Teams"           /></div>
  <div class="rounded-xl border border-gray-200 bg-gray-50 p-4 text-center"><BigValue data={kpis}    value=total_matches  title="Matches Played"  /></div>
  <div class="rounded-xl border border-gray-200 bg-gray-50 p-4 text-center"><BigValue data={kpis}    value=total_goals    title="Goals Scored"    /></div>
</div>

<div class="flex items-center gap-3 mb-4">
  <span class="text-xs font-semibold text-gray-400 uppercase tracking-widest">Explore</span>
  <div class="flex-1 h-px bg-gray-100"></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4" style="grid-auto-rows: 7.5rem">

<a href="/standings" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">🏆</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Standings</div>
      <div class="text-gray-400 text-sm mt-1">Championship, Relegation &amp; Regular Season tables</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/match-results" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">⚽</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Match Results</div>
      <div class="text-gray-400 text-sm mt-1">Full match history, scorelines and analytics by round</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/upcoming-matches" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">📅</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Upcoming Fixtures</div>
      <div class="text-gray-400 text-sm mt-1">Head-to-head history &amp; form guide for upcoming matches</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/league-analytics" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">📈</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">League Intelligence</div>
      <div class="text-gray-400 text-sm mt-1">Standings, points race, team radar & discipline rankings</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/team-analytics" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">👥</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Team Intelligence</div>
      <div class="text-gray-400 text-sm mt-1">Points race, match log, squad depth &amp; home/away splits</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/player-analytics" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">👟</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Player Intelligence</div>
      <div class="text-gray-400 text-sm mt-1">Percentile radar, performance timeline &amp; match-by-match log</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/stadium-analytics" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">🏟️</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Stadium Intelligence</div>
      <div class="text-gray-400 text-sm mt-1">Stadium map, surface effects and home fortress rankings</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/referee-analytics" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">🟨</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Referee Intelligence</div>
      <div class="text-gray-400 text-sm mt-1">Cards, fouls, home/away bias and discipline trends</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/glossary" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">📖</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">Data Glossary</div>
      <div class="text-gray-400 text-sm mt-1">Definitions and formulas for all KPIs and abbreviations</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

<a href="/about" class="flex flex-col justify-center no-underline rounded-xl border border-gray-200 bg-white p-6 hover:border-blue-500 hover:shadow-lg transition-all duration-200 group shadow-sm h-full">
  <div class="flex items-center gap-4">
    <div class="text-3xl">👤</div>
    <div class="flex-1">
      <div class="text-base font-bold text-gray-800 group-hover:text-blue-500 transition-colors">About This Project</div>
      <div class="text-gray-400 text-sm mt-1">The story behind this project, the blog &amp; the author</div>
    </div>
    <div class="translate-x-0 shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 text-lg">→</div>
  </div>
</a>

</div>

<div class="mt-8 text-center text-xs text-gray-400">Data last updated: {last_updated[0]?.last_updated}</div>
