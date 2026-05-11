---
sidebar: never
hide_toc: true
title: Team Analysis
---

```sql seasons
select distinct season from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
order by season desc
```

```sql teams
select distinct team_name as team from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
order by team_name
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

<Dropdown data={teams} name=team value=team label=team>
    <DropdownOption value="FC Copenhagen" valueLabel="FC Copenhagen"/>
</Dropdown>

```sql kpis
select
    sum(points_earned)                                                                          as points,
    count(distinct match_id) filter (where result = 'Win')                                     as wins,
    count(distinct match_id) filter (where result = 'Draw')                                    as draws,
    count(distinct match_id) filter (where result = 'Loss')                                    as losses,
    count(distinct match_id)                                                                    as matches,
    sum(goals_scored)                                                                          as goals_for,
    sum(goals_conceded)                                                                        as goals_against,
    sum(goals_scored) - sum(goals_conceded)                                                    as goal_difference,
    round(100.0 * count(distinct match_id) filter (where result = 'Win') / count(distinct match_id), 1) as win_rate_pct,
    round(sum(xg), 2)                                                                          as total_xg,
    round(sum(goals_scored) - sum(xg), 2)                                                      as xg_overperformance,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                           as avg_possession,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                      as avg_pass_accuracy,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                          as shot_conversion_pct,
    round(sum(goals_scored)::double / count(distinct match_id), 2)                             as avg_goals_scored,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)                           as avg_goals_conceded,
    round(sum(shots_on_goal)::double / count(distinct match_id), 1)                            as avg_shots_on_goal,
    round(sum(saves)::double / count(distinct match_id), 1)                                    as avg_saves,
    round(sum(xg) / count(distinct match_id), 2)                                               as avg_xg_per_match,
    round(sum(fouls)::double / count(distinct match_id), 1)                                    as avg_fouls,
    sum(yellow_cards)                                                                          as yellow_cards,
    sum(red_cards)                                                                             as red_cards,
    round((sum(fouls) + sum(yellow_cards)*5 + sum(red_cards)*15)::double / count(distinct match_id), 1) as aggression_index,
    count(distinct match_id) filter (where goals_conceded = 0)                                 as clean_sheets
from superligaen.mart_match_facts
where team_name   = '${inputs.team.value}'
  and season      = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

```sql team_fingerprint
with all_stats as (
    select
        team_name,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                         as goals_pm,
        round(sum(goals_conceded)::double / count(distinct match_id), 2)                       as conceded_pm,
        round(sum(xg)::double / count(distinct match_id), 2)                                   as xg_pm,
        round(sum(possession_pct)::double / count(distinct match_id), 1)                       as possession,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                  as pass_acc,
        round((sum(fouls) + sum(yellow_cards)*5 + sum(red_cards)*15)::double / count(distinct match_id), 1) as aggression
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name
),
ranked as (
    select
        team_name,
        round(percent_rank() over (order by goals_pm) * 100)           as attack,
        round(percent_rank() over (order by conceded_pm desc) * 100)   as defense,
        round(percent_rank() over (order by xg_pm) * 100)              as xg_quality,
        round(percent_rank() over (order by possession) * 100)         as possession,
        round(percent_rank() over (order by pass_acc) * 100)           as passing,
        round(percent_rank() over (order by aggression desc) * 100)    as discipline
    from all_stats
)
select * from ranked where team_name = '${inputs.team.value}'
```

```sql team_radar_data
select 'Attack'      as dimension, attack      as value from ${team_fingerprint}
union all
select 'Defense',      defense      from ${team_fingerprint}
union all
select 'xG Quality',   xg_quality   from ${team_fingerprint}
union all
select 'Possession',   possession   from ${team_fingerprint}
union all
select 'Passing',      passing      from ${team_fingerprint}
union all
select 'Discipline',   discipline   from ${team_fingerprint}
```

```sql rolling_form
select
    match_round_number                                                                          as round,
    match_date,
    opponent_team_name                                                                         as opponent,
    result,
    goals_scored                                                                               as gf,
    goals_conceded                                                                             as ga,
    xg,
    round(avg(goals_scored::double) over (order by match_round_number rows between 4 preceding and current row), 2) as rolling_gf,
    round(avg(goals_conceded::double) over (order by match_round_number rows between 4 preceding and current row), 2) as rolling_ga,
    round(avg(xg::double) over (order by match_round_number rows between 4 preceding and current row), 2) as rolling_xg
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season    = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_round_number
```

```sql xg_scatter
select
    match_round_number                                                                         as round,
    opponent_team_name                                                                         as opponent,
    xg,
    goals_scored                                                                               as goals,
    result,
    case result when 'Win' then 1 when 'Draw' then 2 else 3 end                               as result_order
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season    = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by result_order, match_round_number
```

```sql home_away
select
    team_side                                                                                  as side,
    count(distinct match_id)                                                                   as matches,
    count(distinct match_id) filter (where result = 'Win')                                    as wins,
    count(distinct match_id) filter (where result = 'Draw')                                   as draws,
    count(distinct match_id) filter (where result = 'Loss')                                   as losses,
    sum(goals_scored)                                                                          as gf,
    sum(goals_conceded)                                                                        as ga,
    round(100.0 * count(distinct match_id) filter (where result = 'Win') / count(distinct match_id), 1) as win_pct,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                          as avg_possession,
    round(sum(shots_on_goal)::double / count(distinct match_id), 1)                           as avg_sog,
    round(sum(xg) / count(distinct match_id), 2)                                              as avg_xg,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                        as shot_conv_pct,
    sum(yellow_cards)                                                                         as yc,
    sum(red_cards)                                                                            as rc,
    round(sum(saves)::double / count(distinct match_id), 1)                                  as avg_saves
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season    = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_side
order by team_side desc
```

---

## {inputs.team.value} — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=points          title="Points"          /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=win_rate_pct    title="Win Rate"        fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=goals_for       title="Goals Scored"    /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=goals_against   title="Goals Conceded"  /></div>
</div>

---

## Performance Fingerprint

<p class="text-sm text-gray-500 mb-1">Percentile rank vs all teams in {inputs.season.value}. The dashed inner polygon shows the league average (50th percentile) on every dimension.</p>

<div class="max-w-lg mx-auto">
  <RadarChart data={team_radar_data} name={inputs.team.value} color="#236aa4" height=400 />
</div>

---

## Form — Rolling 5-Match Average

<p class="text-sm text-gray-500 mb-2">Smoothed over a 5-match window to separate genuine runs of form from single-match outliers.</p>

<LineChart
    data={rolling_form}
    x=round
    y={['rolling_gf', 'rolling_ga', 'rolling_xg']}
    labels={['Goals Scored (5-match avg)', 'Goals Conceded (5-match avg)', 'xG (5-match avg)']}
    xAxisTitle="Round"
    yAxisTitle="Goals / xG"
    title="Rolling Form — {inputs.team.value}"
    colorPalette={['#16a34a', '#dc2626', '#3b82f6']}
    chartAreaHeight=280
/>

---

## Clinical Finishing — xG vs Actual Goals

<p class="text-sm text-gray-500 mb-2">Points above the dashed diagonal overperformed their xG; points below underperformed. Hover for match details.</p>

<ScatterPlot
    data={xg_scatter}
    x=xg
    y=goals
    series=result
    tooltipTitle=opponent
    xAxisTitle="Expected Goals (xG)"
    yAxisTitle="Goals Scored"
    title="xG vs Actual Goals — {inputs.team.value}"
    colorPalette={['#16a34a', '#f59e0b', '#dc2626']}
    chartAreaHeight=300
    echartsOptions={{
        series: [
            {
                markLine: {
                    silent: true,
                    symbol: ['none', 'none'],
                    lineStyle: { type: 'dashed', color: '#9ca3af', width: 1.5 },
                    label: { show: true, formatter: 'xG = Goals', position: 'insideEndBottom', color: '#9ca3af', fontSize: 10 },
                    data: [[ { coord: [0, 0] }, { coord: [5, 5] } ]]
                }
            }
        ]
    }}
/>

---

## Season Summary

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=wins               title="Wins"              /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=draws              title="Draws"             /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=losses             title="Losses"            /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=clean_sheets       title="Clean Sheets"      /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=avg_xg_per_match   title="xG / Match"        /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=xg_overperformance title="xG Overperformance" /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=avg_possession     title="Avg Possession %"  fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=shot_conversion_pct title="Shot Conversion %" fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=avg_shots_on_goal  title="Shots on Goal / Match" /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=avg_saves          title="Saves / Match"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=avg_fouls          title="Fouls / Match"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis} value=aggression_index   title="Aggression Index"  /></div>
</div>

---

## Home vs Away

<DataTable data={home_away}>
    <Column id=side        title="Side"         />
    <Column id=matches     title="MP"    align=center />
    <Column id=wins        title="W"     align=center />
    <Column id=draws       title="D"     align=center />
    <Column id=losses      title="L"     align=center />
    <Column id=gf          title="GF"    align=center />
    <Column id=ga          title="GA"    align=center />
    <Column id=win_pct     title="Win %" align=center fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=avg_possession title="Poss %"  fmt='0.0"%"' />
    <Column id=avg_sog     title="SoG"   />
    <Column id=avg_xg      title="xG"    />
    <Column id=shot_conv_pct title="Conv %" fmt='0.0"%"' />
    <Column id=yc          title="YC"    align=center />
    <Column id=rc          title="RC"    align=center />
    <Column id=avg_saves   title="Saves" />
</DataTable>
