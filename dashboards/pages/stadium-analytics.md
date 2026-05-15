---
sidebar: never
hide_toc: true
title: Stadium Intelligence
---

```sql season_options
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

{#key season_options[0]?.season}
<Dropdown data={season_options} name=season value=season label=season order="season desc" defaultValue={season_options[0]?.season} multiple=true />
{/key}

```sql stadium_stats
select
    stadium_name,
    max(stadium_latitude)                                                                           as lat,
    max(stadium_longitude)                                                                          as lon,
    max(stadium_surface)                                                                            as stadium_surface,
    case
        when max(stadium_surface) ilike '%grass%' or max(stadium_surface) ilike '%natural%' then 1
        when max(stadium_surface) ilike '%artif%' or max(stadium_surface) ilike '%turf%'    then 2
        else 3
    end                                                                                             as surface_code,
    max(stadium_capacity)                                                                           as stadium_capacity,
    count(distinct match_id)                                                                        as total_matches,
    sum(goals_scored)::int                                                                          as total_goals,
    sum(goals_scored) - (min(sum(goals_scored)) over () - 1)                                        as total_goals_scaled,
    round(sum(goals_scored)::double    / count(distinct match_id), 2)                               as goals_per_match,
    round(100.0 * count(*) filter (where team_side='Home' and result='Win')
          / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
    round(100.0 * count(*) filter (where result='Draw')
          / count(*), 1)                                                                            as draw_pct,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as pass_accuracy,
    round(sum(yellow_cards)::double    / count(distinct match_id), 2)                               as yc_per_match,
    round(sum(fouls)::double           / count(distinct match_id), 1)                               as fouls_per_match,
    round(sum(corner_kicks)::double    / count(distinct match_id), 1)                               as corners_per_match
from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
  and stadium_latitude between 54.5 and 57.8
  and stadium_longitude between 7.5 and 15.5
  and stadium_name not like '%Unknown%'
  and stadium_name not like '%Applicable%'
  and season in ${inputs.season.value}
group by stadium_name
having count(distinct match_id) >= 4
order by home_win_pct desc
```

```sql surface_analysis
select
    stadium_surface,
    count(distinct match_id)::int                                                                    as matches,
    round(sum(goals_scored)::double    / count(distinct match_id), 2)                               as goals_per_match,
    round(100.0 * count(*) filter (where team_side='Home' and result='Win')
          / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
    round(100.0 * count(*) filter (where result='Draw') / count(*), 1)                             as draw_pct,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as pass_accuracy,
    round(sum(possession_pct)::double  / count(distinct match_id), 1)                               as avg_possession,
    round(sum(shots_on_goal)::double   / count(distinct match_id), 1)                               as shots_per_match,
    round(sum(yellow_cards)::double    / count(distinct match_id), 2)                               as yc_per_match,
    round(sum(fouls)::double           / count(distinct match_id), 1)                               as fouls_per_match,
    round(sum(corner_kicks)::double    / count(distinct match_id), 1)                               as corners_per_match,
    round(100.0 * sum(goals_scored)    / nullif(sum(total_shots), 0), 1)                            as shot_conversion,
    round(100.0 * sum(crosses_accurate) / nullif(sum(crosses_total), 0), 1)                        as cross_accuracy
from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
  and stadium_surface is not null
  and stadium_surface != ''
  and stadium_latitude between 54.5 and 57.8
  and stadium_longitude between 7.5 and 15.5
  and season in ${inputs.season.value}
group by stadium_surface
order by matches desc
```

```sql fortress_ranking
select
    stadium_name,
    max(stadium_surface)                                                                            as stadium_surface,
    max(stadium_capacity)                                                                           as stadium_capacity,
    mode(team_logo) filter (where team_side='Home')                                                 as team_logo,
    '<img src="' || mode(team_logo) filter (where team_side='Home') || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''">'  as home_team_logo,
    mode(team_name) filter (where team_side='Home')                                                 as home_team,
    count(distinct match_id) filter (where team_side='Home')::int                                  as home_matches,
    sum(case when team_side='Home' and result='Win'  then 1 else 0 end)::int                       as home_wins,
    sum(case when team_side='Home' and result='Draw' then 1 else 0 end)::int                       as home_draws,
    sum(case when team_side='Home' and result='Loss' then 1 else 0 end)::int                       as home_losses,
    round(100.0 * sum(case when team_side='Home' and result='Win' then 1 else 0 end)
          / nullif(count(distinct match_id) filter (where team_side='Home'), 0), 1)                as home_win_pct,
    round(sum(case when team_side='Home' then goals_scored   else 0 end)::double
          / nullif(count(distinct match_id) filter (where team_side='Home'), 0), 2)                as goals_scored_per_match,
    round(sum(case when team_side='Home' then goals_conceded else 0 end)::double
          / nullif(count(distinct match_id) filter (where team_side='Home'), 0), 2)                as goals_conceded_per_match
from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
  and stadium_name not like '%Unknown%'
  and stadium_name not like '%Applicable%'
  and stadium_latitude between 54.5 and 57.8
  and stadium_longitude between 7.5 and 15.5
  and season in ${inputs.season.value}
group by stadium_name
having count(distinct match_id) filter (where team_side='Home') >= 4
order by home_win_pct desc
```

```sql fortress_podium
select * from ${fortress_ranking} limit 3
```

```sql stadium_kpis
select
    count(distinct stadium_name)                                                                              as total_stadiums,
    sum(case when stadium_surface ilike '%grass%' or stadium_surface ilike '%natural%' then 1 else 0 end)    as grass_stadiums,
    sum(case when stadium_surface ilike '%artif%' or stadium_surface ilike '%turf%'    then 1 else 0 end)    as turf_stadiums
from (
    select stadium_name, max(stadium_surface) as stadium_surface
    from superligaen.mart_match_facts
    where result in ('Win','Draw','Loss')
      and stadium_name not like '%Unknown%'
      and stadium_latitude between 54.5 and 57.8
      and stadium_longitude between 7.5 and 15.5
      and season in ${inputs.season.value}
    group by stadium_name
    having count(distinct match_id) >= 4
) t
```

---

## Stadium Intelligence — {inputs.season.value}

<div class="grid grid-cols-3 gap-2 sm:gap-4 mb-6 items-stretch">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-2 sm:p-4 text-center flex flex-col justify-center">
    <BigValue data={stadium_kpis} value=total_stadiums title="Stadiums" />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-2 sm:p-4 text-center flex flex-col justify-center">
    <BigValue data={stadium_kpis} value=grass_stadiums title="Grass" />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-2 sm:p-4 text-center flex flex-col justify-center">
    <BigValue data={stadium_kpis} value=turf_stadiums title="Turf" />
  </div>
</div>

---

## Stadium Map

*Bubble size = total goals scored. Color = playing surface type.*

<BubbleMap
    data={stadium_stats}
    lat=lat
    long=lon
    size=total_goals_scaled
    value=stadium_surface
    pointName=stadium_name
    tooltipType=click
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    legendType=categorical
    legendTitle="Stadium Surface"
    title="Superligaen Stadiums — {inputs.season.value}"
    tooltip={[{id: 'stadium_name', showColumnName: false, valueClass: 'font-bold text-sm'}, {id: 'stadium_surface'}, {id: 'total_goals'}, {id: 'goals_per_match'}]}
/>

---

## Top 3 Fortress Stadiums

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
  {#each fortress_podium as s, i}
    <div class="rounded-2xl border p-5 shadow-md relative
      {i === 0 ? 'border-amber-300 bg-gradient-to-b from-amber-50 to-yellow-100' :
       i === 1 ? 'border-gray-300 bg-gradient-to-b from-gray-50 to-gray-100' :
       'border-orange-200 bg-gradient-to-b from-orange-50 to-amber-50'}">
      <div class="text-2xl mb-3">{i === 0 ? '🥇' : i === 1 ? '🥈' : '🥉'}</div>
      <div class="flex items-center gap-3 mb-4">
        <img src="{s.team_logo}" alt="{s.home_team}" class="h-10 w-10 object-contain drop-shadow" onerror="this.style.display='none'" />
        <div>
          <div class="font-extrabold text-gray-800 text-sm leading-tight">{s.stadium_name}</div>
          <div class="text-xs text-gray-400">{s.home_team}</div>
        </div>
      </div>
      <div class="flex justify-around">
        <div class="text-center">
          <div class="text-2xl font-black text-green-600">{s.home_win_pct}%</div>
          <div class="text-xs text-gray-400 mt-1">Home Win</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-black text-gray-700">{s.home_wins}</div>
          <div class="text-xs text-gray-400 mt-1">Wins</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-black text-gray-500">{s.home_matches}</div>
          <div class="text-xs text-gray-400 mt-1">Home MP</div>
        </div>
      </div>
      <div class="mt-3 text-center text-xs text-gray-400">{s.stadium_surface} · Cap. {s.stadium_capacity}</div>
    </div>
  {/each}
</div>

---

## Surface Analysis: Grass vs Artificial Turf

*How does the playing surface shape the way football is played?*

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=pass_accuracy
    title="Pass Accuracy % by Surface"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=cross_accuracy
    title="Cross Accuracy % by Surface"
    yAxisTitle="Cross Accuracy %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=shot_conversion
    title="Shot Conversion % by Surface"
    yAxisTitle="Shot Conversion %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=fouls_per_match
    title="Fouls per Match by Surface"
    yAxisTitle="Fouls / Match"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
/>

</div>

<DataTable data={surface_analysis}>
    <Column id=stadium_surface  title="Surface"          />
    <Column id=matches          title="Matches"          align=center />
    <Column id=pass_accuracy    title="Pass Acc %"       fmt='0.0"%"' contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=cross_accuracy   title="Cross Acc %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shot_conversion  title="Shot Conv %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=fouls_per_match  title="Fouls/Match"       contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=corners_per_match title="Corners/Match"   />
</DataTable>

---

## Full Fortress Ranking

*Home record at each stadium. A true fortress keeps opponents at bay.*

<BarChart
    data={fortress_ranking}
    x=stadium_name
    y=home_win_pct
    title="Home Win Rate by Stadium — {inputs.season.value}"
    yAxisTitle="Home Win %"
    yFmt='0.0'
    sort=true
    swapXY=true
    colorPalette={['#3b82f6']}
/>

<div class="hidden md:block mt-4">
<DataTable data={fortress_ranking} rows=20>
    <Column id=home_team_logo           title=""                        contentType=html />
    <Column id=home_team                title="Home Team"               />
    <Column id=stadium_name             title="Stadium"                 wrap=true />
    <Column id=stadium_capacity         title="Capacity"                align=center />
    <Column id=home_win_pct             title="Win %"                   fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=home_wins                title="W"                       align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=home_draws               title="D"                       align=center />
    <Column id=home_losses              title="L"                       align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    <Column id=goals_scored_per_match   title="Goals Scored/Match"      />
    <Column id=goals_conceded_per_match title="Goals Conceded/Match"    />
</DataTable>
</div>
<div class="block md:hidden mt-4">
<DataTable data={fortress_ranking} rows=20>
    <Column id=home_team_logo           title=""                        contentType=html />
    <Column id=home_team                title="Home Team"               />
    <Column id=stadium_name             title="Stadium"                 wrap=true />
    <Column id=stadium_capacity         title="Capacity"                align=center />
    <Column id=home_win_pct             title="Win %"                   fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=home_wins                title="W"                       align=center />
    <Column id=home_draws               title="D"                       align=center />
    <Column id=home_losses              title="L"                       align=center />
    <Column id=goals_scored_per_match   title="Goals Scored/Match"      />
    <Column id=goals_conceded_per_match title="Goals Conceded/Match"    />
</DataTable>
</div>

