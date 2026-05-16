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
        count(distinct team_name)                                                                       as total_teams,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as goals_per_match,
        round(100.0 * count(*) filter (where team_side='Home' and result='Win')
              / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
        round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                             as draw_pct,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as yc_per_match,
        round(100.0 * sum(goals_scored) / nullif(sum(big_chances_created), 0), 1)                      as big_chance_conv
    from superligaen.mart_match_facts
    where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
      and team_name in ${inputs.team.value}
      and result in ('Win', 'Draw', 'Loss')
),
prev as (
    select
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as prev_goals_per_match,
        round(100.0 * count(*) filter (where team_side='Home' and result='Win')
              / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as prev_home_win_pct,
        round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                             as prev_draw_pct,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as prev_yc_per_match
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
select curr.*, prev.* from curr cross join prev
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

```sql historical_trends
select
    season,
    round(sum(goals_scored)::double / count(distinct match_id), 2)                                 as goals_per_match,
    round(100.0 * count(*) filter (where team_side='Home' and result='Win')
          / nullif(count(*) filter (where team_side='Home'), 0), 1)                                as home_win_pct,
    round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                            as draw_pct,
    round(sum(yellow_cards)::double / count(distinct match_id), 2)                                 as yc_per_match,
    round(100.0 * sum(goals_scored) / nullif(sum(big_chances_created), 0), 1)                     as big_chance_conv,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                         as pass_accuracy
from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
  and team_name in ${inputs.team.value}
group by season
order by season
```

```sql ht_intelligence
select
    case
        when goals_ht_scored > goals_ht_conceded then 'Leading'
        when goals_ht_scored = goals_ht_conceded then 'Level'
        else 'Trailing'
    end                                                                          as ht_state,
    count(*)::int                                                                as total,
    round(100.0 * sum(case when result='Win'  then 1 else 0 end) / count(*), 1) as win_pct,
    round(100.0 * sum(case when result='Draw' then 1 else 0 end) / count(*), 1) as draw_pct,
    round(100.0 * sum(case when result='Loss' then 1 else 0 end) / count(*), 1) as loss_pct
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
group by 1
order by case ht_state when 'Leading' then 1 when 'Level' then 2 else 3 end
```

```sql possession_paradox
select
    case
        when possession_pct < 40 then '< 40%'
        when possession_pct < 50 then '40–50%'
        when possession_pct < 60 then '50–60%'
        else '≥ 60%'
    end                                                                          as possession_bucket,
    count(*)::int                                                                as matches,
    round(100.0 * sum(case when result='Win'  then 1 else 0 end) / count(*), 1) as win_pct,
    round(100.0 * sum(case when result='Draw' then 1 else 0 end) / count(*), 1) as draw_pct,
    round(100.0 * sum(case when result='Loss' then 1 else 0 end) / count(*), 1) as loss_pct
from superligaen.mart_match_facts
where ('${inputs.season.value}' = 'All Seasons' or season = '${inputs.season.value}')
  and team_name in ${inputs.team.value}
  and result in ('Win', 'Draw', 'Loss')
group by 1
order by min(possession_pct)
```

---

## League Intelligence — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={league_kpis} value=total_goals title="Goals Scored" />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={league_kpis} value=goals_per_match title="Goals / Match" comparison=prev_goals_per_match comparisonTitle="vs prev season" comparisonDelta=true />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={league_kpis} value=home_win_pct title="Home Win %" comparison=prev_home_win_pct comparisonTitle="vs prev season" comparisonDelta=true fmt='0.0"%"' />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={league_kpis} value=yc_per_match title="YC / Match" comparison=prev_yc_per_match comparisonTitle="vs prev season" comparisonDelta=true downIsGood=true />
  </div>
</div>

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

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={team_landscape}
    x=team_name
    y=goals_for
    title="Goals Scored"
    colorPalette={['#22c55e']}
    swapXY=true
    sort=true
/>

<BarChart
    data={team_landscape}
    x=team_name
    y=goals_against
    title="Goals Conceded"
    colorPalette={['#ef4444']}
    swapXY=true
    sort=true
/>

<BarChart
    data={team_landscape}
    x=team_name
    y=clean_sheets
    title="Clean Sheets"
    colorPalette={['#14b8a6']}
    swapXY=true
    sort=true
/>

<BarChart
    data={team_landscape}
    x=team_name
    y=pass_accuracy
    title="Pass Accuracy %"
    colorPalette={['#8b5cf6']}
    swapXY=true
    sort=true
/>

</div>

---

## Tactical Intelligence

### Half-Time State → Full-Time Result

*Once you're ahead at half-time in Superligaen, how likely are you to hold on?*

<div class="grid grid-cols-3 gap-4 mb-8">
  {#each ht_intelligence as row}
    <div class="rounded-2xl border p-5 text-center {row.ht_state === 'Leading' ? 'border-green-200 bg-green-50' : row.ht_state === 'Trailing' ? 'border-red-200 bg-red-50' : 'border-gray-200 bg-gray-50'}">
      <div class="text-2xl mb-2">{row.ht_state === 'Leading' ? '🟢' : row.ht_state === 'Trailing' ? '🔴' : '🟡'}</div>
      <div class="text-xs uppercase tracking-widest font-bold mb-1 {row.ht_state === 'Leading' ? 'text-green-600' : row.ht_state === 'Trailing' ? 'text-red-500' : 'text-gray-500'}">
        {row.ht_state} at HT
      </div>
      <div class="text-sm text-gray-400 mb-4">{row.total} matches</div>
      <div class="flex justify-around">
        <div>
          <div class="text-2xl font-black text-green-600">{row.win_pct}%</div>
          <div class="text-xs text-gray-400 mt-1">Win</div>
        </div>
        <div>
          <div class="text-2xl font-black text-yellow-500">{row.draw_pct}%</div>
          <div class="text-xs text-gray-400 mt-1">Draw</div>
        </div>
        <div>
          <div class="text-2xl font-black text-red-500">{row.loss_pct}%</div>
          <div class="text-xs text-gray-400 mt-1">Loss</div>
        </div>
      </div>
    </div>
  {/each}
</div>

### The Possession Paradox

*More possession doesn't mean more wins. The data tells a counterintuitive story.*

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  {#each possession_paradox as row}
    <div class="rounded-xl border border-gray-200 bg-gray-50 p-4 text-center">
      <div class="text-xs uppercase tracking-widest text-gray-400 font-semibold mb-1">Possession</div>
      <div class="text-lg font-bold text-gray-700 mb-1">{row.possession_bucket}</div>
      <div class="text-xs text-gray-400 mb-3">{row.matches} matches</div>
      <div class="flex justify-around">
        <div>
          <div class="text-xl font-black text-green-600">{row.win_pct}%</div>
          <div class="text-xs text-gray-400">W</div>
        </div>
        <div>
          <div class="text-xl font-black text-yellow-500">{row.draw_pct}%</div>
          <div class="text-xs text-gray-400">D</div>
        </div>
        <div>
          <div class="text-xl font-black text-red-500">{row.loss_pct}%</div>
          <div class="text-xs text-gray-400">L</div>
        </div>
      </div>
    </div>
  {/each}
</div>

---

## 16 Seasons of Data

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<LineChart
    data={historical_trends}
    x=season
    y=goals_per_match
    title="Goals per Match — Historical"
    xAxisTitle="Season"
    yAxisTitle="Goals / Match"
    lineColor="#22c55e"
    sort=false
    chartAreaHeight=220
/>

<LineChart
    data={historical_trends}
    x=season
    y={['home_win_pct','draw_pct']}
    title="Home Win % & Draw % — Historical"
    xAxisTitle="Season"
    yAxisTitle="%"
    yFmt='0.0'
    colorPalette={['#3b82f6','#eab308']}
    sort=false
    chartAreaHeight=220
/>

<LineChart
    data={historical_trends}
    x=season
    y=yc_per_match
    title="Yellow Cards per Match — Historical"
    xAxisTitle="Season"
    yAxisTitle="YC / Match"
    lineColor="#f97316"
    sort=false
    chartAreaHeight=220
/>

<LineChart
    data={historical_trends}
    x=season
    y=pass_accuracy
    title="Pass Accuracy % — Historical"
    xAxisTitle="Season"
    yAxisTitle="Pass Acc %"
    lineColor="#8b5cf6"
    sort=false
    chartAreaHeight=220
/>

</div>
