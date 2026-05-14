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

<Dropdown data={seasons} name=season value=season label=season order="season desc" />

<Dropdown data={teams} name=team value=team label=team defaultValue={teams[0]?.team} />

```sql kpis
select
    sum(points_earned)                                                                         as total_points,
    count(distinct match_id) filter (where result = 'Win')                                     as wins,
    count(distinct match_id) filter (where result = 'Draw')                                    as draws,
    count(distinct match_id) filter (where result = 'Loss')                                    as losses,
    sum(goals_scored)                                                                          as goals_for,
    sum(goals_conceded)                                                                        as goals_against,
    sum(goals_scored) - sum(goals_conceded)                                                    as goal_difference,
    round(100.0 * count(distinct match_id) filter (where result = 'Win') / count(distinct match_id), 1) as win_rate_pct,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                           as avg_possession,
    round(sum(goals_scored)::double / count(distinct match_id), 2)                             as avg_goals_scored,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)                           as avg_goals_conceded,
    round(sum(corner_kicks)::double / count(distinct match_id), 1)                             as avg_corners,
    round(sum(shots_on_goal)::double / count(distinct match_id), 1)                            as avg_shots_on_goal,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                          as shot_conversion_pct,
    round(100.0 * sum(goals_scored) / nullif(sum(shots_on_goal), 0), 1)                        as on_target_conversion_pct,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                      as avg_pass_accuracy,
    round(sum(fouls)::double / count(distinct match_id), 1)                                    as avg_fouls,
    round((sum(fouls) + sum(yellow_cards) * 5 + sum(red_cards) * 15)::double / count(distinct match_id), 1) as aggression_index,
    round(sum(saves)::double / count(distinct match_id), 1)                                    as avg_saves,
    round(sum(offsides)::double / count(distinct match_id), 1)                                 as avg_offsides,
    sum(yellow_cards)                                                                          as yellow_cards,
    sum(red_cards)                                                                             as red_cards
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

```sql form
select
    match_date,
    match_round_name             as round,
    match_round_number,
    opponent_team_name           as opponent,
    team_side                    as side,
    goals_scored                 as gf,
    goals_conceded               as ga,
    result,
    shots_on_goal,
    possession_pct               as possession,
    round(100.0 * passes_accurate / nullif(total_passes, 0), 1) as pass_accuracy,
    corner_kicks,
    fouls,
    offsides,
    yellow_cards,
    red_cards,
    saves
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date asc
```

```sql home_away
select
    team_side                                                                                  as side,
    count(distinct match_id)                                                                   as matches,
    count(distinct match_id) filter (where result = 'Win')                                     as wins,
    count(distinct match_id) filter (where result = 'Draw')                                    as draws,
    count(distinct match_id) filter (where result = 'Loss')                                    as losses,
    sum(goals_scored)                                                                          as goals_for,
    sum(goals_conceded)                                                                        as goals_against,
    round(100.0 * count(distinct match_id) filter (where result = 'Win') / count(distinct match_id), 1) as win_rate_pct,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                           as avg_possession,
    round(sum(shots_on_goal)::double / count(distinct match_id), 1)                            as avg_shots_on_goal,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                          as shot_conversion_pct,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                      as avg_pass_accuracy,
    round(sum(fouls)::double / count(distinct match_id), 1)                                    as avg_fouls,
    round(sum(saves)::double / count(distinct match_id), 1)                                    as avg_saves,
    sum(yellow_cards)                                                                          as yellow_cards,
    sum(red_cards)                                                                             as red_cards
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_side
order by team_side desc
```

---

## {inputs.team.value} — Season Overview

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=total_points     title="Points"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=wins             title="Wins"            /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=draws            title="Draws"           /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=losses           title="Losses"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=goals_for        title="Goals Scored"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=goals_against    title="Goals Conceded"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=goal_difference  title="Goal Difference" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=win_rate_pct     title="Win Rate"        fmt='0.0"%"' /></div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_possession       title="Avg Possession"    fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_pass_accuracy     title="Pass Accuracy"     fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=shot_conversion_pct   title="Shot Conversion"   fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=on_target_conversion_pct title="On-Target Conv." fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=aggression_index     title="Aggression Index"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_saves            title="Avg Saves/Match"   /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_goals_scored     title="Goals Scored/Match"             /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_goals_conceded   title="Goals Conceded/Match"           /></div>
</div>

---

## Points Progression

```sql points_trend
select
    match_date,
    match_round_name               as round,
    match_round_number,
    cumulative_points,
    result,
    opponent_team_name             as opponent,
    goals_scored                   as gf,
    goals_conceded                 as ga
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date asc
```

<LineChart
    data={points_trend}
    x=match_round_number
    y=cumulative_points
    title="Cumulative Points over Time"
    xAxisTitle="Round"
    yAxisTitle="Points"
    lineColor="#3b82f6"
/>

---

## Form Guide

```sql recent_form
select
    match_date,
    match_round_name               as round,
    opponent_team_name             as opponent,
    team_side                      as side,
    goals_scored                   as gf,
    goals_conceded                 as ga,
    result,
    shots_on_goal,
    possession_pct                 as possession,
    round(100.0 * passes_accurate / nullif(total_passes, 0), 1) as pass_accuracy,
    fouls,
    yellow_cards,
    red_cards
from superligaen.mart_match_facts
where team_name = '${inputs.team.value}'
  and season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
limit 10
```

<DataTable data={recent_form} rows=10>
    <Column id=match_date    title="Date"       />
    <Column id=round         title="Round"      />
    <Column id=opponent      title="Opponent"   />
    <Column id=side          title="Side"       />
    <Column id=gf            title="GF"         />
    <Column id=ga            title="GA"         />
    <Column id=result        title="Result"     />
    <Column id=shots_on_goal title="SoG"        align=center />
    <Column id=possession    title="Poss %"     fmt='0.0"%"' />
    <Column id=pass_accuracy title="Pass %"     fmt='0.0"%"' />
    <Column id=fouls         title="Fouls"      align=center />
    <Column id=yellow_cards  title="YC"         align=center />
    <Column id=red_cards     title="RC"         align=center />
</DataTable>

---

## Attack

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_shots_on_goal     title="Shots on Goal/Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_goals_scored      title="Goals Scored/Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=shot_conversion_pct   title="Shot Conversion %"   fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=on_target_conversion_pct title="On-Target Conv. %"  fmt='0.0"%"' /></div>
</div>

<BarChart
    data={form}
    x=match_round_number
    y=gf
    title="Goals Scored per Match"
    xAxisTitle="Round"
    yAxisTitle="Goals"
    colorPalette={['#22c55e']}
/>

<BarChart
    data={form}
    x=match_round_number
    y=shots_on_goal
    title="Shots on Goal per Match"
    xAxisTitle="Round"
    yAxisTitle="Shots on Goal"
    colorPalette={['#3b82f6']}
/>

---

## Defence

<div class="grid grid-cols-2 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_goals_conceded title="Goals Conceded/Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_saves          title="Saves/Match"          /></div>
</div>

<BarChart
    data={form}
    x=match_round_number
    y=ga
    title="Goals Conceded per Match"
    xAxisTitle="Round"
    yAxisTitle="Goals Conceded"
    colorPalette={['#ef4444']}
/>

<BarChart
    data={form}
    x=match_round_number
    y=saves
    title="Goalkeeper Saves per Match"
    xAxisTitle="Round"
    yAxisTitle="Saves"
    colorPalette={['#6366f1']}
/>

---

## Passing & Possession

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_possession     title="Avg Possession %"  fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_pass_accuracy  title="Avg Pass Accuracy" fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_corners        title="Corners/Match"               /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_offsides       title="Offsides/Match"              /></div>
</div>

<BarChart
    data={form}
    x=match_round_number
    y=possession
    title="Possession % per Match"
    xAxisTitle="Round"
    yAxisTitle="Possession %"
    colorPalette={['#14b8a6']}
/>

<BarChart
    data={form}
    x=match_round_number
    y=pass_accuracy
    title="Pass Accuracy % per Match"
    xAxisTitle="Round"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#8b5cf6']}
/>

---

## Discipline

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=avg_fouls        title="Fouls/Match"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=yellow_cards     title="Yellow Cards"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=red_cards        title="Red Cards"        /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={kpis} value=aggression_index title="Aggression Index" /></div>
</div>

<BarChart
    data={form}
    x=match_round_number
    y=fouls
    title="Fouls per Match"
    xAxisTitle="Round"
    yAxisTitle="Fouls"
    colorPalette={['#f97316']}
/>

<BarChart
    data={form}
    x=match_round_number
    y={['yellow_cards', 'red_cards']}
    title="Cards per Match"
    xAxisTitle="Round"
    yAxisTitle="Cards"
    colorPalette={['#eab308', '#dc2626']}
/>

---

## Home vs Away

<div class="overflow-x-auto">
<DataTable data={home_away}>
    <Column id=side                  title="Side"            />
    <Column id=matches               title="MP"              />
    <Column id=wins                  title="W"               />
    <Column id=draws                 title="D"               />
    <Column id=losses                title="L"               />
    <Column id=goals_for             title="GF"              />
    <Column id=goals_against         title="GA"              />
    <Column id=win_rate_pct          title="Win %"           fmt='0.0"%"' />
    <Column id=avg_possession        title="Avg Poss %"      fmt='0.0"%"' />
    <Column id=avg_shots_on_goal     title="Avg SoG"         />
    <Column id=shot_conversion_pct   title="Shot Conv %"     fmt='0.0"%"' />
    <Column id=avg_pass_accuracy     title="Pass Acc %"      fmt='0.0"%"' />
    <Column id=avg_fouls             title="Avg Fouls"       />
    <Column id=avg_saves             title="Avg Saves"       />
    <Column id=yellow_cards          title="YC"              />
    <Column id=red_cards             title="RC"              />
</DataTable>
</div>
