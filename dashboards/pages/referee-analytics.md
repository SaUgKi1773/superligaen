---
sidebar: never
hide_toc: true
title: Referee Intelligence
---

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season defaultValue={seasons[0]?.season} />
{/key}

```sql season_kpis
with curr as (
    select
        count(distinct referee_name)                                                              as total_referees,
        round(sum(yellow_cards)::double  / count(distinct match_id), 2)                          as league_avg_yellows,
        round(sum(red_cards)::double     / count(distinct match_id), 3)                          as league_avg_reds,
        round(sum(fouls)::double         / count(distinct match_id), 1)                          as league_avg_fouls,
        round((sum(yellow_cards) + sum(red_cards) * 3)::double / count(distinct match_id), 2)   as league_severity_index
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
),
prev as (
    select
        round(sum(yellow_cards)::double  / count(distinct match_id), 2)                          as prev_league_avg_yellows,
        round(sum(red_cards)::double     / count(distinct match_id), 3)                          as prev_league_avg_reds,
        round(sum(fouls)::double         / count(distinct match_id), 1)                          as prev_league_avg_fouls,
        round((sum(yellow_cards) + sum(red_cards) * 3)::double / count(distinct match_id), 2)   as prev_league_severity_index
    from superligaen.mart_match_facts
    where season = (
        select max(season) from superligaen.mart_match_facts
        where season < '${inputs.season.value}' and result in ('Win', 'Draw', 'Loss')
    )
      and result in ('Win', 'Draw', 'Loss')
)
select curr.*, prev.* from curr cross join prev
```

```sql season_stats
select
    referee_name,
    count(distinct match_id)::int                                                                        as matches_managed,
    sum(yellow_cards)::int                                                                               as total_yellow_cards,
    sum(red_cards)::int                                                                                  as total_red_cards,
    sum(fouls)::int                                                                                      as total_fouls,
    round(sum(yellow_cards)::double  / count(distinct match_id), 2)                                     as avg_yellows_per_match,
    round(sum(red_cards)::double     / count(distinct match_id), 3)                                     as avg_reds_per_match,
    round(sum(fouls)::double         / count(distinct match_id), 1)                                     as avg_fouls_per_match,
    round((sum(yellow_cards) + sum(red_cards) * 3)::double / count(distinct match_id), 2)               as card_severity_index,
    round(sum(case when team_side='Home' then yellow_cards else 0 end)::double
          / count(distinct match_id), 2)                                                                 as home_yc_per_match,
    round(sum(case when team_side='Away' then yellow_cards else 0 end)::double
          / count(distinct match_id), 2)                                                                 as away_yc_per_match,
    round(100.0 * sum(case when team_side='Home' then yellow_cards else 0 end)
          / nullif(sum(yellow_cards), 0), 1)                                                             as home_yc_pct
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by referee_name
order by matches_managed desc
```

```sql top3_strictest
select * from ${season_stats} order by avg_yellows_per_match desc limit 3
```

```sql top3_lenient
select * from ${season_stats} order by avg_yellows_per_match asc limit 3
```

```sql historical_trends
select
    season,
    round(sum(yellow_cards)::double  / count(distinct match_id), 2)                               as yc_per_match,
    round(sum(red_cards)::double     / count(distinct match_id), 4)                               as rc_per_match,
    round(sum(fouls)::double         / count(distinct match_id), 1)                               as fouls_per_match,
    round((sum(yellow_cards) + sum(red_cards) * 3)::double / count(distinct match_id), 2)         as severity_index
from superligaen.mart_match_facts
where result in ('Win', 'Draw', 'Loss')
group by season
order by season asc
```

---

## Referee Intelligence — {inputs.season.value}

### League Discipline Snapshot

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={season_kpis} value=total_referees title="Active Referees" />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={season_kpis} value=league_avg_yellows title="Avg YC / Match" comparison=prev_league_avg_yellows comparisonTitle="vs last season" comparisonDelta=true downIsGood=true />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={season_kpis} value=league_avg_reds title="Avg RC / Match" comparison=prev_league_avg_reds comparisonTitle="vs last season" comparisonDelta=true downIsGood=true />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={season_kpis} value=league_avg_fouls title="Avg Fouls / Match" comparison=prev_league_avg_fouls comparisonTitle="vs last season" comparisonDelta=true downIsGood=true />
  </div>
</div>

---

## Strictest vs Most Lenient Referees

<div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">

<div>
  <div class="text-sm font-bold text-red-500 uppercase tracking-widest mb-3">🟨 Strictest</div>
  <div class="flex flex-col gap-3">
    {#each top3_strictest as r, i}
      <div class="rounded-xl border border-red-100 bg-gradient-to-r from-red-50 to-orange-50 p-4 flex items-center gap-4">
        <div class="text-2xl font-black text-red-400 w-8 text-center">{i+1}</div>
        <div class="flex-1">
          <div class="font-bold text-gray-800">{r.referee_name}</div>
          <div class="text-xs text-gray-400 mt-0.5">{r.matches_managed} games · {r.total_yellow_cards} yellows · {r.total_red_cards} reds</div>
        </div>
        <div class="text-right">
          <div class="text-xl font-black text-red-500">{r.avg_yellows_per_match}</div>
          <div class="text-xs text-gray-400">YC/match</div>
        </div>
      </div>
    {/each}
  </div>
</div>

<div>
  <div class="text-sm font-bold text-green-500 uppercase tracking-widest mb-3">🟩 Most Lenient</div>
  <div class="flex flex-col gap-3">
    {#each top3_lenient as r, i}
      <div class="rounded-xl border border-green-100 bg-gradient-to-r from-green-50 to-teal-50 p-4 flex items-center gap-4">
        <div class="text-2xl font-black text-green-400 w-8 text-center">{i+1}</div>
        <div class="flex-1">
          <div class="font-bold text-gray-800">{r.referee_name}</div>
          <div class="text-xs text-gray-400 mt-0.5">{r.matches_managed} games · {r.total_yellow_cards} yellows · {r.total_red_cards} reds</div>
        </div>
        <div class="text-right">
          <div class="text-xl font-black text-green-600">{r.avg_yellows_per_match}</div>
          <div class="text-xs text-gray-400">YC/match</div>
        </div>
      </div>
    {/each}
  </div>
</div>

</div>

---

## Season Leaderboard

<DataTable data={season_stats} rows=20>
    <Column id=referee_name          title="Referee"              wrap=true />
    <Column id=matches_managed       title="Games"                contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=total_yellow_cards    title="Yellow Cards"         contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards       title="Red Cards"            contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=avg_yellows_per_match title="Avg YC / Match"       contentType=colorscale colorPalette={['white','#eab308']} />
    <Column id=avg_reds_per_match    title="Avg RC / Match"       contentType=colorscale colorPalette={['white','#ef4444']} />
    <Column id=avg_fouls_per_match   title="Avg Fouls / Match"    contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=card_severity_index   title="Severity Index"       contentType=colorscale colorPalette={['white','#dc2626']} />
    <Column id=home_yc_pct           title="Home YC %"            fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

---

## Home / Away Bias

*A neutral referee should book home and away teams equally. Values near 50% = balanced. Above 50% = more cards to home team.*

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={season_stats}
    x=referee_name
    y={['home_yc_per_match','away_yc_per_match']}
    title="YC per Match — Home vs Away Teams"
    yAxisTitle="YC / Match"
    colorPalette={['#3b82f6','#f97316']}
    swapXY=true
    type=stacked
/>

<BarChart
    data={season_stats}
    x=referee_name
    y=home_yc_pct
    title="% of Yellow Cards Given to Home Team"
    yAxisTitle="Home YC %"
    yFmt='0.0'
    colorPalette={['#6366f1']}
    swapXY=true
    sort=true
/>

</div>

---

## Cards & Fouls per Match

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={season_stats}
    x=referee_name
    y={['avg_yellows_per_match','avg_reds_per_match']}
    title="Cards per Match — {inputs.season.value}"
    colorPalette={['#eab308','#ef4444']}
    swapXY=true
    sort=true
/>

<BarChart
    data={season_stats}
    x=referee_name
    y=avg_fouls_per_match
    title="Fouls per Match — {inputs.season.value}"
    colorPalette={['#f97316']}
    swapXY=true
    sort=true
/>

</div>

---

## Historical Discipline Trends

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<LineChart
    data={historical_trends}
    x=season
    y=yc_per_match
    title="Yellow Cards per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="YC / Match"
    lineColor="#eab308"
    sort=false
/>

<LineChart
    data={historical_trends}
    x=season
    y=fouls_per_match
    title="Fouls per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="Fouls / Match"
    lineColor="#f97316"
    sort=false
/>

<LineChart
    data={historical_trends}
    x=season
    y=severity_index
    title="Card Severity Index — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="Severity Index"
    lineColor="#dc2626"
    sort=false
/>

<LineChart
    data={historical_trends}
    x=season
    y=rc_per_match
    title="Red Cards per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="RC / Match"
    lineColor="#ef4444"
    sort=false
/>

</div>

---

## Referee Deep Dive

<Dropdown data={season_stats} name=referee value=referee_name label=referee_name />

```sql referee_team_exposure
select
    team_name,
    count(distinct match_id)::int as matches
from superligaen.mart_match_facts
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name
order by matches desc
```

```sql referee_match_log
select
    match_date,
    match_round_name                    as round,
    match_name,
    score,
    sum(yellow_cards)::int              as yellow_cards,
    sum(red_cards)::int                 as red_cards,
    sum(fouls)::int                     as fouls
from superligaen.mart_match_facts
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by match_date, match_round_name, match_name, score
order by match_date desc
```

```sql referee_kpis
select * from ${season_stats}
where referee_name = '${inputs.referee.value}'
```

{#each referee_kpis as r}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="text-center md:text-left">
    <div class="text-3xl font-extrabold text-white mb-1">{r.referee_name}</div>
    <div class="text-gray-400 text-sm mb-5">{inputs.season.value} · {r.matches_managed} matches officiated</div>
    <div class="flex flex-wrap justify-center md:justify-start gap-6">
      <div class="text-center">
        <div class="text-3xl font-black text-yellow-400">{r.total_yellow_cards}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Yellow Cards</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-red-400">{r.total_red_cards}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Red Cards</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-orange-400">{r.avg_yellows_per_match}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">YC / Match</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-white">{r.avg_fouls_per_match}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Fouls / Match</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-purple-400">{r.card_severity_index}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Severity Index</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black {r.home_yc_pct > 55 ? 'text-red-400' : r.home_yc_pct < 45 ? 'text-blue-400' : 'text-green-400'}">{r.home_yc_pct}%</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Home YC %</div>
      </div>
    </div>
  </div>
</div>
{/each}

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

### Team Exposure

<BarChart
    data={referee_team_exposure}
    x=team_name
    y=matches
    title="Matches per Team — {inputs.referee.value}"
    colorPalette={['#6366f1']}
    swapXY=true
/>

</div>

<div>

### Match Log

<DataTable data={referee_match_log} rows=10>
    <Column id=match_date    title="Date"   />
    <Column id=round         title="Round"  />
    <Column id=match_name    title="Match"  wrap=true />
    <Column id=score         title="Score"  align=center />
    <Column id=yellow_cards  title="YC"     contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards     title="RC"     contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=fouls         title="Fouls"  contentType=colorscale colorPalette={['white','#f97316']} align=center />
</DataTable>

</div>

</div>
