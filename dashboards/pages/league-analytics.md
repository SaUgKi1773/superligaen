---
sidebar: never
hide_toc: true
title: League Analysis
---

```sql seasons
select distinct season from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql league_kpis
select
    count(distinct match_id) / 2                                                              as total_matches,
    sum(goals_scored) / 2                                                                     as total_goals,
    round(sum(goals_scored)::double / count(distinct match_id), 2)                           as avg_goals_per_match,
    round(sum(xg) / count(distinct match_id), 2)                                             as avg_xg_per_match,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                        as avg_shot_conversion,
    round(sum(yellow_cards)::double / (count(distinct match_id) / 2), 1)                     as avg_yellow_per_match
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

```sql attack_defense
with stats as (
    select
        team_name,
        sum(points_earned)                                                                     as points,
        count(distinct match_id)                                                               as matches,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                        as goals_pm,
        round(sum(goals_conceded)::double / count(distinct match_id), 2)                      as conceded_pm,
        round(sum(xg)::double / count(distinct match_id), 2)                                  as xg_pm
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name
),
avgs as (
    select avg(goals_pm) as avg_goals, avg(conceded_pm) as avg_conceded from stats
)
select
    s.team_name,
    s.points,
    s.matches,
    s.goals_pm,
    s.conceded_pm,
    s.xg_pm,
    case
        when s.goals_pm >= a.avg_goals and s.conceded_pm <= a.avg_conceded then 'Dominant'
        when s.goals_pm >= a.avg_goals and s.conceded_pm  > a.avg_conceded then 'High Scoring'
        when s.goals_pm  < a.avg_goals and s.conceded_pm <= a.avg_conceded then 'Defensive'
        else 'Struggling'
    end as quadrant
from stats s cross join avgs a
order by s.points desc
```

```sql league_avg
select
    round(avg(goals_pm), 2)   as avg_goals_pm,
    round(avg(conceded_pm), 2) as avg_conceded_pm
from (
    select
        round(sum(goals_scored)::double / count(distinct match_id), 2) as goals_pm,
        round(sum(goals_conceded)::double / count(distinct match_id), 2) as conceded_pm
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name
)
```

```sql points_progression
select
    match_round_number as round,
    team_name,
    cumulative_points,
    cumulative_gd,
    cumulative_gf
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by max(cumulative_points) over (partition by team_name) desc, team_name, match_round_number
```

```sql performance_heatmap
with stats as (
    select
        team_name,
        sum(points_earned)                                                                      as points,
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
        points,
        round(percent_rank() over (order by goals_pm) * 100)           as attack_pct,
        round(percent_rank() over (order by conceded_pm desc) * 100)   as defense_pct,
        round(percent_rank() over (order by xg_pm) * 100)              as xg_pct,
        round(percent_rank() over (order by possession) * 100)         as possession_pct,
        round(percent_rank() over (order by pass_acc) * 100)           as passing_pct,
        round(percent_rank() over (order by aggression desc) * 100)    as discipline_pct
    from stats
)
select team_name, points, 'Attack'      as metric, attack_pct      as pct from ranked
union all
select team_name, points, 'Defense',    defense_pct    from ranked
union all
select team_name, points, 'xG Quality', xg_pct         from ranked
union all
select team_name, points, 'Possession', possession_pct from ranked
union all
select team_name, points, 'Passing',    passing_pct    from ranked
union all
select team_name, points, 'Discipline', discipline_pct from ranked
order by points desc, team_name
```

## {inputs.season.value} — League Analysis

<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=total_matches         title="Matches Played"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=total_goals            title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=avg_goals_per_match     title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=avg_xg_per_match        title="Avg xG / Match"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=avg_shot_conversion     title="Shot Conversion %"  fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_kpis} value=avg_yellow_per_match    title="Avg YC / Match"     /></div>
</div>

---

## Points Progression

<LineChart
    data={points_progression}
    x=round
    y=cumulative_points
    series=team_name
    xAxisTitle="Round"
    yAxisTitle="Cumulative Points"
    title="Points Progression by Round"
    chartAreaHeight=310
    legend=false
    echartsOptions={{tooltip: {formatter: (function() { const lookup = {}; for (const row of points_progression) { if (!lookup[row.round]) lookup[row.round] = {}; lookup[row.round][row.team_name] = {gd: row.cumulative_gd, gf: row.cumulative_gf}; } return function(params) { const round = params[0].value[0]; const roundData = lookup[round] || {}; const sorted = [...params].sort((a, b) => { if (b.value[1] !== a.value[1]) return b.value[1] - a.value[1]; const pa = roundData[a.seriesName] || {gd: 0, gf: 0}; const pb = roundData[b.seriesName] || {gd: 0, gf: 0}; if (pb.gd !== pa.gd) return pb.gd - pa.gd; return pb.gf - pa.gf; }); let out = '<span style="font-weight:600;">Round ' + round + '</span>'; for (const p of sorted) { out += '<br><span style="font-size:11px;">' + p.marker + ' ' + p.seriesName + '</span><span style="float:right;margin-left:10px;font-size:12px;">' + p.value[1] + '</span>'; } return out; }; })()}}}
/>

---

## Attack vs Defense — Team Quadrant

<p class="text-sm text-gray-500 mb-2">Goals scored per match (attacking output) vs goals conceded per match (defensive solidity). Dashed lines show league averages. Hover a point to see the team.</p>

<ScatterPlot
    data={attack_defense}
    x=goals_pm
    y=conceded_pm
    series=quadrant
    tooltipTitle=team_name
    xAxisTitle="Goals Scored / Match  →  more clinical"
    yAxisTitle="Goals Conceded / Match  ↓  more solid"
    title="Attack vs Defense — {inputs.season.value}"
    colorPalette={['#16a34a', '#3b82f6', '#f59e0b', '#dc2626']}
    chartAreaHeight=360
    echartsOptions={{
        yAxis: { inverse: true },
        series: [
            {
                label: { show: true, formatter: '{b}', fontSize: 10, color: '#374151', position: 'right' },
                markLine: {
                    silent: true,
                    symbol: ['none','none'],
                    lineStyle: { type: 'dashed', color: '#d1d5db', width: 1 },
                    label: { show: false },
                    data: [
                        { xAxis: league_avg[0]?.avg_goals_pm ?? 0 },
                        { yAxis: league_avg[0]?.avg_conceded_pm ?? 0 }
                    ]
                }
            },
            { label: { show: true, formatter: '{b}', fontSize: 10, color: '#374151', position: 'right' } },
            { label: { show: true, formatter: '{b}', fontSize: 10, color: '#374151', position: 'right' } },
            { label: { show: true, formatter: '{b}', fontSize: 10, color: '#374151', position: 'right' } }
        ]
    }}
/>

---

## Team Performance Fingerprints

<p class="text-sm text-gray-500 mb-3">Percentile rank within the league for each dimension. Green = top of the league, red = bottom. Teams sorted by points.</p>

<Heatmap
    data={performance_heatmap}
    x=metric
    y=team_name
    value=pct
    title="All Dimensions — Percentile Rankings"
    colorPalette={['#fca5a5', '#fde68a', '#86efac']}
    chartAreaHeight=320
    echartsOptions={{
        xAxis: { splitArea: { show: true } },
        yAxis: { splitArea: { show: true } },
        visualMap: { show: false }
    }}
/>
