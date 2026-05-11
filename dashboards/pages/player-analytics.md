---
sidebar: never
hide_toc: true
title: Player Analysis
---

```sql seasons
select distinct season from superligaen.mart_player_appearances
order by season desc
```

```sql positions
select 'All Positions' as position
union all
select distinct player_position
from superligaen.mart_player_appearances
where player_position is not null
  and player_position not in ('Unknown Player Name', 'Not Applicable Player Name')
order by position
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

<Dropdown data={positions} name=position value=position label=position>
    <DropdownOption value="All Positions" valueLabel="All Positions"/>
</Dropdown>

```sql player_season_stats
select
    player_name,
    player_position                                                                            as position,
    team_name                                                                                  as team,
    count(distinct match_id)                                                                   as matches,
    sum(minutes_played)                                                                        as minutes,
    sum(goals_scored)                                                                          as goals,
    sum(assists)                                                                               as assists,
    sum(goals_scored) + sum(assists)                                                           as contributions,
    sum(passes_key)                                                                            as key_passes,
    sum(tackles_total)                                                                         as tackles,
    sum(interceptions)                                                                         as interceptions,
    sum(yellow_cards)                                                                          as yellow_cards,
    sum(red_cards)                                                                             as red_cards,
    round(avg(rating) filter (where rating is not null), 2)                                   as avg_rating,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)                       as goals_p90,
    round(sum(assists) * 90.0 / nullif(sum(minutes_played), 0), 2)                            as assists_p90,
    round((sum(goals_scored) + sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2)      as contributions_p90
from superligaen.mart_player_appearances
where season = '${inputs.season.value}'
  and ('${inputs.position.value}' = 'All Positions' or player_position = '${inputs.position.value}')
group by player_name, player_position, team_name
having sum(minutes_played) >= 270
order by contributions desc, avg_rating desc nulls last
```

```sql league_player_kpis
select
    count(distinct player_name)                                                               as total_players,
    sum(goals_scored)                                                                         as total_goals,
    sum(assists)                                                                              as total_assists,
    round(avg(rating) filter (where rating is not null), 2)                                  as avg_rating
from superligaen.mart_player_appearances
where season = '${inputs.season.value}'
  and ('${inputs.position.value}' = 'All Positions' or player_position = '${inputs.position.value}')
```

```sql top_contributors
select
    player_name,
    team,
    goals_p90,
    assists_p90,
    contributions_p90
from ${player_season_stats}
where contributions_p90 > 0
order by contributions_p90 desc
limit 20
```

```sql minutes_rating
select
    player_name,
    team,
    position,
    minutes,
    avg_rating,
    goals,
    assists,
    contributions
from ${player_season_stats}
where avg_rating is not null
order by avg_rating desc
```

## {inputs.season.value} — Player Analysis

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_player_kpis} value=total_players  title="Players"           /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_player_kpis} value=total_goals    title="Goals Scored"      /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_player_kpis} value=total_assists   title="Assists"           /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={league_player_kpis} value=avg_rating      title="Avg Player Rating" /></div>
</div>

---

## Top Performers

<p class="text-sm text-gray-500 mb-3">Minimum 270 minutes played. Click a column header to sort.</p>

<DataTable data={player_season_stats} rows=20 search=true>
    <Column id=player_name    title="Player"       wrap=true />
    <Column id=position       title="Position"     />
    <Column id=team           title="Team"         wrap=true />
    <Column id=matches        title="MP"           align=center />
    <Column id=minutes        title="Mins"         align=center />
    <Column id=goals          title="G"            align=center contentType=colorscale colorPalette={['white','#16a34a']} />
    <Column id=assists        title="A"            align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=contributions  title="G+A"          align=center contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=key_passes     title="KP"           align=center />
    <Column id=avg_rating     title="Rating"       contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=goals_p90      title="G/90"         />
    <Column id=assists_p90    title="A/90"         />
    <Column id=contributions_p90 title="G+A/90"   contentType=bar colorPalette={['#8b5cf6']} />
</DataTable>

---

## Goal Contributions per 90 — Top 20

<p class="text-sm text-gray-500 mb-2">Goals and assists per 90 minutes. Filters for players with 270+ minutes to remove small-sample outliers.</p>

<BarChart
    data={top_contributors}
    x=player_name
    y={['goals_p90', 'assists_p90']}
    labels={['Goals / 90', 'Assists / 90']}
    title="Goal Contributions per 90 Minutes — Top 20"
    xAxisTitle="Player"
    yAxisTitle="Per 90 Minutes"
    colorPalette={['#16a34a', '#3b82f6']}
    swapXY=true
    chartAreaHeight=420
/>

---

## Minutes Played vs Average Rating

<p class="text-sm text-gray-500 mb-2">Players in the top-right are consistent performers. Top-left are high-impact squad players. Hover for details.</p>

<ScatterPlot
    data={minutes_rating}
    x=minutes
    y=avg_rating
    series=position
    tooltipTitle=player_name
    xAxisTitle="Total Minutes Played"
    yAxisTitle="Average Match Rating"
    title="Playing Time vs Performance Rating"
    chartAreaHeight=360
    echartsOptions={{
        series: [
            { label: { show: false } },
            { label: { show: false } },
            { label: { show: false } },
            { label: { show: false } }
        ]
    }}
/>
