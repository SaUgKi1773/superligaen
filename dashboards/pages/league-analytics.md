---
sidebar: never
hide_toc: true
title: League Intelligence
---

<script>
  import TeamRadar from '../../components/TeamRadar.svelte';

  const scatterPalette = ['#3b82f6','#ef4444','#22c55e','#f59e0b','#8b5cf6','#ec4899','#14b8a6','#f97316','#6366f1','#84cc16','#06b6d4','#a855f7'];
  let selectedTeam = null;
  function toggleTeam(name) { selectedTeam = selectedTeam === name ? null : name; }
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current, 0 as sort_key
  from superligaen.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
  union all
  select 'All Seasons', -1, 1
)
order by sort_key, is_current desc, season desc
```

```sql teams
select distinct team_name
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and result in ('Win', 'Draw', 'Loss')
order by team_name
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

<Dropdown data={teams} name=team value=team_name label=team_name multiple=true selectAllByDefault=true />

```sql league_kpis
with curr as (
    select
        count(distinct match_id)                                                                        as total_matches,
        sum(goals_scored)                                                                               as total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as goals_per_match,
        round(100.0 * count(*) filter (where team_side='Home' and result='Win')
              / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
        round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                              as draw_pct,
        round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                               as shot_conversion,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as pass_accuracy,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as yc_per_match,
        round(sum(red_cards)::double / count(distinct match_id), 2)                                    as rc_per_match,
        round(sum(shots_on_goal)::double / count(distinct match_id), 1)                                as sot_per_match
    from superligaen.mart_match_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
),
prev as (
    select
        sum(goals_scored)                                                                               as prev_total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as prev_goals_per_match,
        round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                              as prev_draw_pct,
        round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                               as prev_shot_conversion,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as prev_pass_accuracy,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as prev_yc_per_match,
        round(sum(red_cards)::double / count(distinct match_id), 2)                                    as prev_rc_per_match,
        round(sum(shots_on_goal)::double / count(distinct match_id), 1)                                as prev_sot_per_match
    from superligaen.mart_match_facts
    where season = (
        select max(season) from superligaen.mart_match_facts
        where season < '${inputs.season.value}'
          and result in ('Win','Draw','Loss')
          and '${inputs.season.value}' != 'All Seasons'
    )
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
)
select
    curr.*,
    prev.*,
    round(curr.total_goals       / nullif(prev.prev_total_goals,       0), 2) as total_goals_ratio,
    round(curr.goals_per_match   / nullif(prev.prev_goals_per_match,   0), 2) as goals_ratio,
    round(curr.shot_conversion   / nullif(prev.prev_shot_conversion,   0), 2) as shot_conv_ratio,
    round(curr.pass_accuracy     / nullif(prev.prev_pass_accuracy,     0), 2) as pass_ratio,
    round(curr.yc_per_match      / nullif(prev.prev_yc_per_match,      0), 2) as yc_ratio,
    round(curr.rc_per_match      / nullif(prev.prev_rc_per_match,      0), 2) as rc_ratio,
    round(curr.sot_per_match     / nullif(prev.prev_sot_per_match,     0), 2) as sot_ratio
from curr cross join prev
```

```sql season_awards
with goals_ranked as (
    select player_name, player_photo, team_name, team_logo,
           sum(goals_scored)::int as total_goals,
           row_number() over (order by sum(goals_scored) desc) as rn
    from superligaen.mart_player_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, team_name, team_logo
    having sum(goals_scored) > 0
),
assists_ranked as (
    select player_name, player_photo, team_name, team_logo,
           sum(assists)::int as total_assists,
           row_number() over (order by sum(assists) desc) as rn
    from superligaen.mart_player_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, team_name, team_logo
    having sum(assists) > 0
),
rating_ranked as (
    select player_name, player_photo, team_name, team_logo,
           round(avg(rating), 2) as avg_rating,
           count(distinct match_id)::int as matches,
           row_number() over (order by avg(rating) desc) as rn
    from superligaen.mart_player_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
      and rating is not null
      and rating > 0
    group by player_name, player_photo, team_name, team_logo
    having count(distinct match_id) >= 5
)
select
    g.player_name  as top_scorer_name,
    g.player_photo as top_scorer_photo,
    g.team_name    as top_scorer_team,
    g.team_logo    as top_scorer_logo,
    g.total_goals,
    a.player_name  as top_assister_name,
    a.player_photo as top_assister_photo,
    a.team_name    as top_assister_team,
    a.team_logo    as top_assister_logo,
    a.total_assists,
    r.player_name  as best_rated_name,
    r.player_photo as best_rated_photo,
    r.team_name    as best_rated_team,
    r.team_logo    as best_rated_logo,
    r.avg_rating,
    r.matches      as best_rated_matches
from goals_ranked   g
cross join assists_ranked a
cross join rating_ranked  r
where g.rn = 1 and a.rn = 1 and r.rn = 1
```

```sql current_standings
select
    team_name,
    team_short_name,
    count(distinct match_id)                          as mp,
    sum(points_earned)                                as pts,
    sum(goals_scored) - sum(goals_conceded)           as gd,
    sum(goals_scored)                                 as gf,
    standings_type                                    as round_group
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
group by team_name, team_short_name, standings_type
order by
    case standings_type
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        else                           3
    end,
    pts desc, gd desc, gf desc
```

```sql team_landscape
select
    team_name,
    team_logo,
    sum(goals_scored)::int                                                                   as goals_for,
    sum(goals_conceded)::int                                                                 as goals_against,
    sum(points_earned)::int                                                                  as points,
    round(100.0 * count(*) filter (where result='Win') / count(*), 1)                       as win_pct,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                       as shot_conv,
    count(distinct match_id) filter (where goals_conceded = 0)::int                         as clean_sheets,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                   as pass_accuracy
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
group by team_name, team_logo
order by team_name
```

```sql points_progression
select match_round_number as round, team_name, cumulative_points, cumulative_gd, cumulative_gf
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
order by max(cumulative_points) over (partition by team_name) desc, team_name, match_round_number
```

```sql team_season_stats
select
    team_name,
    sum(goals_scored)::int                                                                              as goals_for,
    sum(goals_conceded)::int                                                                            as goals_against,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                                  as shot_conversion_pct,
    round(100.0 * sum(goals_scored) / nullif(sum(shots_on_goal), 0), 1)                                as on_target_conversion_pct,
    count(distinct match_id) filter (where goals_conceded = 0)::int                                    as clean_sheets,
    round(sum(saves)::double / count(distinct match_id), 1)                                            as avg_saves,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)                                   as avg_goals_conceded,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                                   as avg_possession,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                              as avg_pass_accuracy,
    round(sum(corner_kicks)::double / count(distinct match_id), 1)                                     as avg_corners,
    round(sum(fouls)::double / count(distinct match_id), 1)                                            as avg_fouls,
    round((sum(fouls) + sum(yellow_cards) * 5 + sum(red_cards) * 15)::double / count(distinct match_id), 1) as aggression_index,
    sum(yellow_cards)::int                                                                              as yellow_cards,
    sum(red_cards)::int                                                                                 as red_cards
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
group by team_name
```

```sql attack_rankings
select team_name, goals_for, shot_conversion_pct, on_target_conversion_pct
from ${team_season_stats}
order by goals_for desc
```

```sql defence_rankings
select team_name, goals_against, clean_sheets, avg_saves, avg_goals_conceded
from ${team_season_stats}
order by clean_sheets desc
```

```sql possession_rankings
select team_name, avg_possession, avg_pass_accuracy, avg_corners
from ${team_season_stats}
order by avg_possession desc
```

```sql discipline_rankings
select team_name, yellow_cards, red_cards, avg_fouls, aggression_index
from ${team_season_stats}
order by aggression_index desc
```

```sql radar_data
with all_teams as (
    select
        team_name,
        sum(goals_scored)::double       / count(distinct match_id)                         as goals_per_match,
        sum(goals_conceded)::double     / count(distinct match_id)                         as conceded_per_match,
        100.0 * sum(passes_accurate)    / nullif(sum(total_passes), 0)                     as pass_accuracy,
        sum(possession_pct)::double     / count(distinct match_id)                         as avg_possession,
        100.0 * sum(goals_scored)       / nullif(sum(total_shots), 0)                      as shot_conv,
        100.0 * sum(case when result='Win' then 1 else 0 end) / count(distinct match_id)  as win_rate
    from superligaen.mart_match_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and result in ('Win', 'Draw', 'Loss')
    group by team_name
),
ranked as (
    select
        team_name,
        goals_per_match,
        conceded_per_match,
        pass_accuracy,
        avg_possession,
        shot_conv,
        win_rate,
        round(percent_rank() over (order by goals_per_match)         * 100) as attack_pct,
        round(percent_rank() over (order by conceded_per_match desc)  * 100) as defense_pct,
        round(percent_rank() over (order by pass_accuracy)           * 100) as passing_pct,
        round(percent_rank() over (order by avg_possession)          * 100) as possession_pct,
        round(percent_rank() over (order by shot_conv)               * 100) as efficiency_pct,
        round(percent_rank() over (order by win_rate)                * 100) as wins_pct
    from all_teams
)
select * from ranked where team_name in ${inputs.team.value} order by team_name
```

---

## League Intelligence — {inputs.season.value}

{#each league_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Total Goals</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.total_goals}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_total_goals ?? '—'}</span>
      {#if k.total_goals_ratio != null}<span class="text-sm font-bold {k.total_goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.total_goals_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_goals_per_match ?? '—'}</span>
      {#if k.goals_ratio != null}<span class="text-sm font-bold {k.goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.goals_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Draw %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.draw_pct}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_draw_pct != null ? k.prev_draw_pct + '%' : '—'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Conversion %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_conversion}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_shot_conversion != null ? k.prev_shot_conversion + '%' : '—'}</span>
      {#if k.shot_conv_ratio != null}<span class="text-sm font-bold {k.shot_conv_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.shot_conv_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.pass_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_pass_accuracy != null ? k.prev_pass_accuracy + '%' : '—'}</span>
      {#if k.pass_ratio != null}<span class="text-sm font-bold {k.pass_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.pass_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">YC / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.yc_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_yc_per_match ?? '—'}</span>
      {#if k.yc_ratio != null}<span class="text-sm font-bold {k.yc_ratio <= 1 ? 'text-green-600' : 'text-red-500'}">{k.yc_ratio <= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shots on Target / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.sot_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_sot_per_match ?? '—'}</span>
      {#if k.sot_ratio != null}<span class="text-sm font-bold {k.sot_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.sot_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">RC / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.rc_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_rc_per_match ?? '—'}</span>
      {#if k.rc_ratio != null}<span class="text-sm font-bold {k.rc_ratio <= 1 ? 'text-green-600' : 'text-red-500'}">{k.rc_ratio <= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

</div>
{/each}

---

## Standings & Points Race

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-start">

<div>

<LineChart
    data={points_progression}
    x=round
    y=cumulative_points
    series=team_name
    xAxisTitle="Round"
    yAxisTitle="Cumulative Points"
    title="Points Race"
    echartsOptions={{tooltip: {formatter: (function() { const lookup = {}; for (const row of points_progression) { if (!lookup[row.round]) lookup[row.round] = {}; lookup[row.round][row.team_name] = {gd: row.cumulative_gd, gf: row.cumulative_gf}; } return function(params) { const round = params[0].value[0]; const roundData = lookup[round] || {}; const sorted = [...params].sort((a, b) => { if (b.value[1] !== a.value[1]) return b.value[1] - a.value[1]; const pa = roundData[a.seriesName] || {gd: 0, gf: 0}; const pb = roundData[b.seriesName] || {gd: 0, gf: 0}; if (pb.gd !== pa.gd) return pb.gd - pa.gd; return pb.gf - pa.gf; }); let out = '<span style="font-weight:600;">Round ' + round + '</span>'; for (const p of sorted) { out += '<br><span style="font-size:11px;">' + p.marker + ' ' + p.seriesName + '</span><span style="float:right;margin-left:10px;font-size:12px;">' + p.value[1] + '</span>'; } return out; }; })()}}}
    legend=false
    chartAreaHeight=300
/>

</div>

<div>

#### League Table

<div class="block md:hidden">
<DataTable data={current_standings} rows=20>
    <Column id=team_short_name title="Team"  />
    <Column id=round_group     title="Group" />
    <Column id=mp              title="MP"   align=center />
    <Column id=pts             title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={current_standings} rows=20>
    <Column id=team_name   title="Team"  />
    <Column id=round_group title="Group" />
    <Column id=mp          title="MP"   align=center />
    <Column id=pts         title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>

</div>

</div>

---

## Season Awards

{#if inputs.season.value !== 'All Seasons'}

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">

  {#each season_awards as award}

  <!-- Top Scorer -->
  <div class="relative rounded-2xl overflow-hidden bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow-md p-6">
    <div class="absolute top-3 right-4 text-3xl">⚽</div>
    <div class="text-xs uppercase tracking-widest text-amber-600 font-bold mb-4">Top Scorer</div>
    <div class="flex items-center gap-4">
      <img src="{award.top_scorer_photo}" alt="{award.top_scorer_name}" class="w-16 h-16 rounded-full object-cover border-2 border-amber-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{award.top_scorer_name}</div>
        <div class="flex items-center gap-2 mt-1">
          <img src="{award.top_scorer_logo}" alt="{award.top_scorer_team}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
          <span class="text-sm text-gray-500">{award.top_scorer_team}</span>
        </div>
      </div>
    </div>
    <div class="mt-4 text-4xl font-black text-amber-500">{award.total_goals} <span class="text-base font-normal text-gray-500">goals</span></div>
  </div>

  <!-- Top Assister -->
  <div class="relative rounded-2xl overflow-hidden bg-gradient-to-br from-blue-50 to-sky-100 border border-blue-200 shadow-md p-6">
    <div class="absolute top-3 right-4 text-3xl">🎯</div>
    <div class="text-xs uppercase tracking-widest text-blue-600 font-bold mb-4">Top Assister</div>
    <div class="flex items-center gap-4">
      <img src="{award.top_assister_photo}" alt="{award.top_assister_name}" class="w-16 h-16 rounded-full object-cover border-2 border-blue-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{award.top_assister_name}</div>
        <div class="flex items-center gap-2 mt-1">
          <img src="{award.top_assister_logo}" alt="{award.top_assister_team}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
          <span class="text-sm text-gray-500">{award.top_assister_team}</span>
        </div>
      </div>
    </div>
    <div class="mt-4 text-4xl font-black text-blue-500">{award.total_assists} <span class="text-base font-normal text-gray-500">assists</span></div>
  </div>

  <!-- Best Rated -->
  <div class="relative rounded-2xl overflow-hidden bg-gradient-to-br from-purple-50 to-violet-100 border border-purple-200 shadow-md p-6">
    <div class="absolute top-3 right-4 text-3xl">⭐</div>
    <div class="text-xs uppercase tracking-widest text-purple-600 font-bold mb-4">Best Rated</div>
    <div class="flex items-center gap-4">
      <img src="{award.best_rated_photo}" alt="{award.best_rated_name}" class="w-16 h-16 rounded-full object-cover border-2 border-purple-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{award.best_rated_name}</div>
        <div class="flex items-center gap-2 mt-1">
          <img src="{award.best_rated_logo}" alt="{award.best_rated_team}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
          <span class="text-sm text-gray-500">{award.best_rated_team}</span>
        </div>
      </div>
    </div>
    <div class="mt-4 text-4xl font-black text-purple-500">{award.avg_rating} <span class="text-base font-normal text-gray-500">avg rating ({award.best_rated_matches} games)</span></div>
  </div>

  {/each}

</div>

{/if}

---

## Team Landscape & Radar

*Where does each team sit on the attack vs defence spectrum? Teams to the right score more, teams lower down concede less. The bottom-right corner is where champions live.*

*How does a team rank across six dimensions relative to the rest of the league? Each axis is a score from 0 to 100 — 100 means best in the league. Click a team in the legend to isolate it.*

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-end">

<div>

<ScatterPlot
    data={team_landscape}
    x=goals_for
    y=goals_against
    series=team_name
    xAxisTitle="Goals Scored"
    yAxisTitle="Goals Conceded"
    title="Attack vs Defence — {inputs.season.value}"
    tooltipColumns={[{id: 'team_name', title: 'Team'}, {id: 'goals_for', title: 'Goals For'}, {id: 'goals_against', title: 'Goals Against'}, {id: 'points', title: 'Points'}, {id: 'win_pct', title: 'Win %', fmt: '0.0"%"'}]}
    chartAreaHeight=320
    legend=false
    echartsOptions={{series: team_landscape.map((row, i) => ({name: row.team_name, itemStyle: {color: selectedTeam === null || row.team_name === selectedTeam ? scatterPalette[i % 12] : '#d1d5db'}}))}}
/>
<div style="display:flex;flex-wrap:wrap;gap:6px 14px;justify-content:center;margin-top:2px;">
  {#each team_landscape as row, i}
  <div
    on:click={() => toggleTeam(row.team_name)}
    style="display:flex;align-items:center;gap:5px;font-size:11px;cursor:pointer;transition:opacity 0.15s;
           opacity:{selectedTeam === null || selectedTeam === row.team_name ? 1 : 0.35};
           color:{selectedTeam === row.team_name ? scatterPalette[i % 12] : '#374151'};
           font-weight:{selectedTeam === row.team_name ? '700' : '400'};"
  >
    <div style="width:10px;height:10px;border-radius:50%;background:{scatterPalette[i % 12]};flex-shrink:0;"></div>
    {row.team_name}
  </div>
  {/each}
</div>

</div>

<div>

<TeamRadar data={radar_data} />

</div>

</div>

---

## Team Rankings

### Attack — Who's Scoring?

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={attack_rankings}
    x=team_name
    y=goals_for
    title="Goals Scored"
    yAxisTitle="Goals"
    colorPalette={['#22c55e']}
    swapXY=true
    sort=true
/>

<BarChart
    data={attack_rankings}
    x=team_name
    y=shot_conversion_pct
    title="Shot Conversion %"
    yAxisTitle="Conversion %"
    colorPalette={['#f59e0b']}
    swapXY=true
    sort=true
/>

</div>

---

### Defence — Who's Keeping Clean Sheets?

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={defence_rankings}
    x=team_name
    y=clean_sheets
    title="Clean Sheets"
    yAxisTitle="Clean Sheets"
    colorPalette={['#14b8a6']}
    swapXY=true
    sort=true
/>

<BarChart
    data={defence_rankings}
    x=team_name
    y=goals_against
    title="Goals Conceded"
    yAxisTitle="Goals Conceded"
    colorPalette={['#ef4444']}
    swapXY=true
    sort=true
/>

</div>

---

### Possession & Passing

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={possession_rankings}
    x=team_name
    y=avg_possession
    title="Average Possession %"
    yAxisTitle="Possession %"
    colorPalette={['#8b5cf6']}
    swapXY=true
    sort=true
/>

<BarChart
    data={possession_rankings}
    x=team_name
    y=avg_pass_accuracy
    title="Average Pass Accuracy %"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#0ea5e9']}
    swapXY=true
    sort=true
/>

</div>

---

### Discipline

<BarChart
    data={discipline_rankings}
    x=team_name
    y=aggression_index
    title="Aggression Index — Fouls + Cards Weighted"
    yAxisTitle="Aggression Index"
    colorPalette={['#f97316']}
    swapXY=true
    sort=true
/>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6 mb-6">

<BarChart
    data={discipline_rankings}
    x=team_name
    y=yellow_cards
    title="Yellow Cards"
    yAxisTitle="Yellow Cards"
    colorPalette={['#eab308']}
    swapXY=true
    sort=true
/>

<BarChart
    data={discipline_rankings}
    x=team_name
    y=red_cards
    title="Red Cards"
    yAxisTitle="Red Cards"
    colorPalette={['#dc2626']}
    swapXY=true
    sort=true
/>

</div>

