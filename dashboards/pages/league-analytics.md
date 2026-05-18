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
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
)
order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from superligaen.mart_match_facts
  where season = '${inputs.season.value}'
    and result in ('Win', 'Draw', 'Loss')
) order by ord, team_name
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

<Dropdown data={teams} name=team value=team_name label=team_name multiple=true defaultValue={['All']} />

```sql league_kpis
with curr as (
    select
        count(distinct match_id)                                                                        as total_matches,
        sum(goals_scored)                                                                               as total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as goals_per_match,
        round(100.0 * count(*) filter (where team_side='Home' and result='Win')
              / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
        round(100.0 * sum(crosses_accurate) / nullif(sum(crosses_total), 0), 1)                          as cross_accuracy,
        round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                               as shot_conversion,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as pass_accuracy,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as yc_per_match,
        round(sum(red_cards)::double / count(distinct match_id), 2)                                    as rc_per_match,
        round(sum(shots_on_goal)::double / count(distinct match_id), 1)                                as sot_per_match
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
),
prev as (
    select
        sum(goals_scored)                                                                               as prev_total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as prev_goals_per_match,
        round(100.0 * sum(crosses_accurate) / nullif(sum(crosses_total), 0), 1)                          as prev_cross_accuracy,
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
    )
      and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
)
select
    curr.*,
    prev.*,
    round(curr.total_goals       / nullif(prev.prev_total_goals,       0), 2) as total_goals_ratio,
    round(curr.goals_per_match   / nullif(prev.prev_goals_per_match,   0), 2) as goals_ratio,
    round(curr.cross_accuracy    / nullif(prev.prev_cross_accuracy,    0), 2) as cross_accuracy_ratio,
    round(curr.shot_conversion   / nullif(prev.prev_shot_conversion,   0), 2) as shot_conv_ratio,
    round(curr.pass_accuracy     / nullif(prev.prev_pass_accuracy,     0), 2) as pass_ratio,
    round(curr.yc_per_match      / nullif(prev.prev_yc_per_match,      0), 2) as yc_ratio,
    round(curr.rc_per_match      / nullif(prev.prev_rc_per_match,      0), 2) as rc_ratio,
    round(curr.sot_per_match     / nullif(prev.prev_sot_per_match,     0), 2) as sot_ratio
from curr cross join prev
```

```sql scorers
with ranked as (
    select
        player_name, player_photo, team_name,
        sum(goals_scored)::int                              as goals,
        row_number() over (order by sum(goals_scored) desc) as rn
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, team_name
    having sum(goals_scored) > 0
)
select * from ranked where rn <= 3 order by rn
```

```sql assisters
with ranked as (
    select
        player_name, player_photo, team_name,
        sum(assists)::int                              as assists,
        row_number() over (order by sum(assists) desc) as rn
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, team_name
    having sum(assists) > 0
)
select * from ranked where rn <= 3 order by rn
```

```sql top_rated
with ranked as (
    select
        player_name, player_photo, team_name,
        round(avg(rating), 2)                        as avg_rating,
        count(distinct match_id)::int                as matches,
        row_number() over (order by avg(rating) desc) as rn
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
      and rating is not null
      and rating > 0
    group by player_name, player_photo, team_name
    having count(distinct match_id) >= 5
)
select * from ranked where rn <= 3 order by rn
```

```sql current_standings
select
    team_name,
    team_short_name,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_name       || '</span></div>' as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_short_name || '</span></div>' as team_col_mobile,
    count(distinct match_id)                          as mp,
    sum(points_earned)                                as pts,
    sum(goals_scored) - sum(goals_conceded)           as gd,
    sum(goals_scored)                                 as gf,
    standings_type                                    as round_group
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ('Win', 'Draw', 'Loss')
group by team_name, team_short_name, team_logo, standings_type
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
where season = '${inputs.season.value}'
  and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ('Win', 'Draw', 'Loss')
group by team_name, team_logo
order by team_name
```

```sql team_landscape_bounds
select
    floor(min(goals_for)  * 0.9)  as x_min,
    ceil(max(goals_for)   * 1.1)  as x_max,
    floor(min(goals_against) * 0.9) as y_min,
    ceil(max(goals_against)  * 1.1) as y_max
from (
    select
        sum(goals_scored)::int   as goals_for,
        sum(goals_conceded)::int as goals_against
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name
)
```

```sql points_progression
select match_round_number as round, team_name, cumulative_points, cumulative_gd, cumulative_gf
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
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
where season = '${inputs.season.value}'
  and ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value})
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
    where season = '${inputs.season.value}'
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
select * from ranked where ('All' in ${inputs.team.value} OR team_name in ${inputs.team.value}) order by team_name
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
    <div class="text-xs text-gray-500 text-center mb-2">Cross Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.cross_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_cross_accuracy != null ? k.prev_cross_accuracy + '%' : '—'}</span>
      {#if k.cross_accuracy_ratio != null}<span class="text-sm font-bold {k.cross_accuracy_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.cross_accuracy_ratio >= 1 ? '▲' : '▼'}</span>{/if}
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
      {#if k.yc_ratio != null}<span class="text-sm font-bold {k.yc_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.yc_ratio >= 1 ? '▲' : '▼'}</span>{/if}
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
      {#if k.rc_ratio != null}<span class="text-sm font-bold {k.rc_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.rc_ratio >= 1 ? '▲' : '▼'}</span>{/if}
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
    <Column id=team_col_mobile title="Team"  contentType=html />
    <Column id=round_group     title="Group" />
    <Column id=mp              title="MP"   align=center />
    <Column id=pts             title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={current_standings} rows=20>
    <Column id=team_col    title="Team"  contentType=html />
    <Column id=round_group title="Group" />
    <Column id=mp          title="MP"   align=center />
    <Column id=pts         title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>

</div>

</div>

---

## Season Awards

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">

{#if scorers.length > 0}
<div style="position: relative;">

  <!-- Scorer rank 1 -->
  <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow-lg p-5" style="position: relative; z-index: 3;">
    <div class="text-xs uppercase tracking-widest text-amber-600 font-bold mb-3">⚽ Top Scorer</div>
    <div class="flex items-center gap-4">
      <img src="{scorers[0].player_photo}" alt="{scorers[0].player_name}" class="w-16 h-16 rounded-full object-cover border-2 border-amber-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{scorers[0].player_name}</div>
        <div class="text-sm text-gray-500 mt-0.5">{scorers[0].team_name}</div>
      </div>
    </div>
    <div class="mt-3 text-3xl font-black text-amber-500 text-right">{scorers[0].goals} <span class="text-base font-normal text-gray-500">goals</span></div>
  </div>

  {#if scorers.length > 1}
  <!-- Scorer rank 2 peek -->
  <div style="position: relative; z-index: 2; margin-top: -10px; overflow: hidden; height: 60px; margin-left: 8px; margin-right: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.12); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow p-3" style="opacity: 0.88;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-amber-400 flex-shrink-0">2</span>
          <span class="text-sm font-bold text-gray-800 truncate">{scorers[1].player_name}</span>
        </div>
        <span class="text-sm font-black text-amber-500 flex-shrink-0">{scorers[1].goals} <span class="text-xs font-normal text-gray-400">goals</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{scorers[1].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #fde68a;"></div>
  </div>
  {/if}

  {#if scorers.length > 2}
  <!-- Scorer rank 3 peek -->
  <div style="position: relative; z-index: 1; margin-top: -10px; overflow: hidden; height: 52px; margin-left: 24px; margin-right: 8px; box-shadow: 0 3px 8px rgba(0,0,0,0.08); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow-sm p-3" style="opacity: 0.72;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-amber-300 flex-shrink-0">3</span>
          <span class="text-sm font-bold text-gray-700 truncate">{scorers[2].player_name}</span>
        </div>
        <span class="text-sm font-black text-amber-400 flex-shrink-0">{scorers[2].goals} <span class="text-xs font-normal text-gray-400">goals</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{scorers[2].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #fde68a;"></div>
  </div>
  {/if}

</div>
{/if}

{#if assisters.length > 0}
<div style="position: relative;">

  <!-- Assister rank 1 -->
  <div class="rounded-2xl bg-gradient-to-br from-blue-50 to-sky-100 border border-blue-200 shadow-lg p-5" style="position: relative; z-index: 3;">
    <div class="text-xs uppercase tracking-widest text-blue-600 font-bold mb-3">🎯 Top Assister</div>
    <div class="flex items-center gap-4">
      <img src="{assisters[0].player_photo}" alt="{assisters[0].player_name}" class="w-16 h-16 rounded-full object-cover border-2 border-blue-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{assisters[0].player_name}</div>
        <div class="text-sm text-gray-500 mt-0.5">{assisters[0].team_name}</div>
      </div>
    </div>
    <div class="mt-3 text-3xl font-black text-blue-500 text-right">{assisters[0].assists} <span class="text-base font-normal text-gray-500">assists</span></div>
  </div>

  {#if assisters.length > 1}
  <!-- Assister rank 2 peek -->
  <div style="position: relative; z-index: 2; margin-top: -10px; overflow: hidden; height: 60px; margin-left: 8px; margin-right: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.12); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-blue-50 to-sky-100 border border-blue-200 shadow p-3" style="opacity: 0.88;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-blue-400 flex-shrink-0">2</span>
          <span class="text-sm font-bold text-gray-800 truncate">{assisters[1].player_name}</span>
        </div>
        <span class="text-sm font-black text-blue-500 flex-shrink-0">{assisters[1].assists} <span class="text-xs font-normal text-gray-400">assists</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{assisters[1].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #bfdbfe;"></div>
  </div>
  {/if}

  {#if assisters.length > 2}
  <!-- Assister rank 3 peek -->
  <div style="position: relative; z-index: 1; margin-top: -10px; overflow: hidden; height: 52px; margin-left: 24px; margin-right: 8px; box-shadow: 0 3px 8px rgba(0,0,0,0.08); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-blue-50 to-sky-100 border border-blue-200 shadow-sm p-3" style="opacity: 0.72;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-blue-300 flex-shrink-0">3</span>
          <span class="text-sm font-bold text-gray-700 truncate">{assisters[2].player_name}</span>
        </div>
        <span class="text-sm font-black text-blue-400 flex-shrink-0">{assisters[2].assists} <span class="text-xs font-normal text-gray-400">assists</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{assisters[2].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #bfdbfe;"></div>
  </div>
  {/if}

</div>
{/if}

{#if top_rated.length > 0}
<div style="position: relative;">

  <!-- Rated rank 1 -->
  <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-violet-100 border border-purple-200 shadow-lg p-5" style="position: relative; z-index: 3;">
    <div class="text-xs uppercase tracking-widest text-purple-600 font-bold mb-3">⭐ Best Rated</div>
    <div class="flex items-center gap-4">
      <img src="{top_rated[0].player_photo}" alt="{top_rated[0].player_name}" class="w-16 h-16 rounded-full object-cover border-2 border-purple-300 shadow" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{top_rated[0].player_name}</div>
        <div class="text-sm text-gray-500 mt-0.5">{top_rated[0].team_name}</div>
      </div>
    </div>
    <div class="mt-3 text-3xl font-black text-purple-500 text-right">{top_rated[0].avg_rating} <span class="text-base font-normal text-gray-500">rating</span></div>
  </div>

  {#if top_rated.length > 1}
  <!-- Rated rank 2 peek -->
  <div style="position: relative; z-index: 2; margin-top: -10px; overflow: hidden; height: 60px; margin-left: 8px; margin-right: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.12); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-violet-100 border border-purple-200 shadow p-3" style="opacity: 0.88;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-purple-400 flex-shrink-0">2</span>
          <span class="text-sm font-bold text-gray-800 truncate">{top_rated[1].player_name}</span>
        </div>
        <span class="text-sm font-black text-purple-500 flex-shrink-0">{top_rated[1].avg_rating} <span class="text-xs font-normal text-gray-400">rating</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{top_rated[1].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #ddd6fe;"></div>
  </div>
  {/if}

  {#if top_rated.length > 2}
  <!-- Rated rank 3 peek -->
  <div style="position: relative; z-index: 1; margin-top: -10px; overflow: hidden; height: 52px; margin-left: 24px; margin-right: 8px; box-shadow: 0 3px 8px rgba(0,0,0,0.08); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-violet-100 border border-purple-200 shadow-sm p-3" style="opacity: 0.72;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-purple-300 flex-shrink-0">3</span>
          <span class="text-sm font-bold text-gray-700 truncate">{top_rated[2].player_name}</span>
        </div>
        <span class="text-sm font-black text-purple-400 flex-shrink-0">{top_rated[2].avg_rating} <span class="text-xs font-normal text-gray-400">rating</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{top_rated[2].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #ddd6fe;"></div>
  </div>
  {/if}

</div>
{/if}

</div>


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
    xMin={team_landscape_bounds[0].x_min}
    xMax={team_landscape_bounds[0].x_max}
    yMin={team_landscape_bounds[0].y_min}
    yMax={team_landscape_bounds[0].y_max}
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

<TeamRadar data={radar_data} title="Performance Radar" />

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

