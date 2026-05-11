---
sidebar: never
hide_toc: true
title: Referee Analysis
---

```sql seasons
select distinct season from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql season_stats
select
    referee_name,
    count(distinct match_id)                                                                   as matches,
    sum(yellow_cards)                                                                          as yellow_cards,
    sum(red_cards)                                                                             as red_cards,
    sum(fouls)                                                                                 as total_fouls,
    round(sum(yellow_cards)::double / count(distinct match_id), 2)                            as avg_yellows_pm,
    round(sum(red_cards)::double / count(distinct match_id), 3)                               as avg_reds_pm,
    round(sum(fouls)::double / count(distinct match_id), 1)                                   as avg_fouls_pm,
    round((sum(yellow_cards) + sum(red_cards) * 3)::double / count(distinct match_id), 2)    as card_severity_index
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by referee_name
order by matches desc
```

```sql season_totals
select
    count(distinct referee_name)                                              as total_referees,
    round(sum(yellow_cards)::double / sum(matches), 2)                       as league_avg_yellows,
    round(sum(red_cards)::double / sum(matches), 3)                          as league_avg_reds,
    round(sum(total_fouls)::double / sum(matches), 1)                        as league_avg_fouls,
    round(sum(card_severity_index * matches) / sum(matches), 2)              as league_avg_severity
from ${season_stats}
```

## Referee Analysis — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={season_totals} value=total_referees      title="Referees Active"    /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={season_totals} value=league_avg_yellows  title="Avg YC / Match"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={season_totals} value=league_avg_reds     title="Avg RC / Match"     /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={season_totals} value=league_avg_fouls    title="Avg Fouls / Match"  /></div>
</div>

---

## Season Leaderboard

<DataTable data={season_stats} rows=20>
    <Column id=referee_name         title="Referee"            wrap=true />
    <Column id=matches              title="Games"              contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=yellow_cards         title="Yellow Cards"       contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards            title="Red Cards"          contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=avg_yellows_pm       title="Avg YC / Match"     contentType=colorscale colorPalette={['white','#eab308']} />
    <Column id=avg_reds_pm          title="Avg RC / Match"     contentType=colorscale colorPalette={['white','#ef4444']} />
    <Column id=avg_fouls_pm         title="Fouls / Match"      contentType=bar        colorPalette={['#f97316']} />
    <Column id=card_severity_index  title="Card Severity"      contentType=colorscale colorPalette={['white','#dc2626']} />
</DataTable>

---

## Strictness Analysis — Fouls Called vs Card Rate

<p class="text-sm text-gray-500 mb-2">Referees in the top-right call many fouls <em>and</em> issue many cards — strict across the board. Bottom-right call many fouls but few cards (lenient). Hover for the referee's name.</p>

<ScatterPlot
    data={season_stats}
    x=avg_fouls_pm
    y=card_severity_index
    tooltipTitle=referee_name
    xAxisTitle="Fouls Called per Match"
    yAxisTitle="Card Severity Index (YC×1 + RC×3 per match)"
    title="Referee Strictness — {inputs.season.value}"
    chartAreaHeight=320
    echartsOptions={{
        series: [{
            label: {
                show: true,
                formatter: '{b}',
                fontSize: 10,
                color: '#374151',
                position: 'right'
            },
            markLine: {
                silent: true,
                symbol: ['none','none'],
                lineStyle: { type: 'dashed', color: '#d1d5db', width: 1 },
                label: { show: false },
                data: [
                    { xAxis: season_totals[0]?.league_avg_fouls ?? 0 },
                    { yAxis: season_totals[0]?.league_avg_severity ?? 0 }
                ]
            }
        }]
    }}
/>

---

## Referee Deep Dive

<Dropdown data={season_stats} name=referee value=referee_name label=referee_name />

```sql referee_kpis
select * from ${season_stats}
where referee_name = '${inputs.referee.value}'
```

```sql referee_team_exposure
select
    team_name,
    count(distinct match_id) as matches
from superligaen.mart_match_facts
where referee_name  = '${inputs.referee.value}'
  and season        = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name
order by matches desc
```

```sql referee_match_log
select
    match_date,
    match_round_name                as round,
    match_name,
    score,
    sum(yellow_cards)               as yellow_cards,
    sum(red_cards)                  as red_cards,
    sum(fouls)                      as total_fouls
from superligaen.mart_match_facts
where referee_name  = '${inputs.referee.value}'
  and season        = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by match_date, match_round_name, match_name, score
order by match_date desc
```

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6 mt-4">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={referee_kpis} value=matches           title="Games"              /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={referee_kpis} value=yellow_cards      title="Yellow Cards"       /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={referee_kpis} value=red_cards         title="Red Cards"          /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={referee_kpis} value=avg_fouls_pm      title="Avg Fouls / Match"  /></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

#### Team Exposure

<BarChart
    data={referee_team_exposure}
    x=team_name
    y=matches
    title="Matches per Team — {inputs.referee.value}"
    colorPalette={['#6366f1']}
    swapXY=true
    chartAreaHeight=280
/>

</div>

<div>

#### Match Log

<DataTable data={referee_match_log} rows=10>
    <Column id=match_date    title="Date"   />
    <Column id=round         title="Round"  />
    <Column id=match_name    title="Match"  wrap=true />
    <Column id=score         title="Score"  align=center />
    <Column id=yellow_cards  title="YC"     contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards     title="RC"     contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=total_fouls   title="Fouls"  contentType=bar colorPalette={['#f97316']} />
</DataTable>

</div>

</div>
