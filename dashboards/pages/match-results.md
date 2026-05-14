---
sidebar: never
hide_toc: true
title: Match Results
---

```sql seasons
select distinct season from superligaen.mart_match_facts
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc" />

```sql rounds
select distinct cast(match_round_number as integer) as round_number
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by 1 desc
```

{#key `${inputs.season.value}|${rounds[0]?.round_number}`}
<Dropdown data={rounds} name=round value=round_number label=round_number multiple=true defaultValue={[rounds[0]?.round_number]} order="round_number desc" />
{/key}

```sql results
select
    match_id,
    match_date,
    match_round_name                as round,
    match_round_number,
    match_name,
    match_short_name,
    score,
    sum(goals_scored)               as total_goals,
    sum(shots_on_goal)              as total_shots_on_goal,
    sum(yellow_cards)               as total_yellow_cards,
    sum(red_cards)                  as total_red_cards,
    sum(corner_kicks)               as total_corners,
    season
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) in ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_id, match_date, match_round_name, match_round_number, match_name, match_short_name, score, season
order by match_date desc
```

```sql round_kpis
select
    sum(total_goals)                                                                    as total_goals,
    round(sum(total_goals)::double / count(distinct match_id), 2)                      as avg_goals_per_match,
    round(sum(total_shots_on_goal)::double / count(distinct match_id), 1)              as avg_shots_on_goal
from ${results}
```

## Match Results — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_goals         title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_goals_per_match  title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_shots_on_goal    title="Avg Shots on Goal"  /></div>
</div>

<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=round               title="Round"          />
    <Column id=match_name          title="Match"          wrap=true />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots_on_goal title="Shots on Goal"  contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=total_corners       title="Corners"        contentType=colorscale colorPalette={['white','#a855f7']} align=center />
</DataTable>

---

## Match Analysis

```sql match_options
select
    match_name || '|' || cast(match_date as varchar) as match_key,
    match_name || '  (' || score || ')'              as match_label,
    match_date
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) in ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_name, match_date, score
order by match_date desc
```

{#key match_options[0]?.match_key}
<Dropdown data={match_options} name=match value=match_key label=match_label defaultValue={match_options[0]?.match_key} order="match_date desc" />
{/key}

```sql mc
select
    max(case when team_side = 'Home' then team_name end)                         as home_team,
    max(case when team_side = 'Away' then team_name end)                         as away_team,
    max(score)                                                                   as score,
    max(case when team_side = 'Home' then goals_scored end)                      as home_goals,
    max(case when team_side = 'Away' then goals_scored end)                      as away_goals,
    max(case when team_side = 'Home' then shots_on_goal end)                     as home_sog,
    max(case when team_side = 'Away' then shots_on_goal end)                     as away_sog,
    max(case when team_side = 'Home' then possession_pct end)                    as home_possession,
    max(case when team_side = 'Away' then possession_pct end)                    as away_possession,
    round(max(case when team_side = 'Home' then passes_accurate end)::double / nullif(max(case when team_side = 'Home' then total_passes end), 0) * 100, 1) as home_pass_accuracy,
    round(max(case when team_side = 'Away' then passes_accurate end)::double / nullif(max(case when team_side = 'Away' then total_passes end), 0) * 100, 1) as away_pass_accuracy,
    max(case when team_side = 'Home' then corner_kicks end)                      as home_corners,
    max(case when team_side = 'Away' then corner_kicks end)                      as away_corners,
    max(case when team_side = 'Home' then fouls end)                             as home_fouls,
    max(case when team_side = 'Away' then fouls end)                             as away_fouls,
    max(case when team_side = 'Home' then offsides end)                          as home_offsides,
    max(case when team_side = 'Away' then offsides end)                          as away_offsides,
    max(case when team_side = 'Home' then yellow_cards end)                      as home_yc,
    max(case when team_side = 'Away' then yellow_cards end)                      as away_yc,
    max(case when team_side = 'Home' then red_cards end)                         as home_rc,
    max(case when team_side = 'Away' then red_cards end)                         as away_rc,
    max(case when team_side = 'Home' then saves end)                             as home_saves,
    max(case when team_side = 'Away' then saves end)                             as away_saves
from superligaen.mart_match_facts
where match_name            = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and season                = '${inputs.season.value}'
```

<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2">

  <div class="grid grid-cols-3 text-center border-b border-gray-200 pb-4 mb-2">
    <div class="text-left font-bold text-lg text-blue-600">{mc[0]?.home_team}<div class="text-xs font-normal text-gray-400">Home</div></div>
    <div class="text-center text-2xl font-bold text-gray-700">{mc[0]?.score}</div>
    <div class="text-right font-bold text-lg text-orange-500">{mc[0]?.away_team}<div class="text-xs font-normal text-gray-400">Away</div></div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_goals}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Goals</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_goals}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0) > 0 ? (mc[0]?.home_goals ?? 0) / ((mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_sog}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Shots on Goal</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_sog}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0) > 0 ? (mc[0]?.home_sog ?? 0) / ((mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_possession}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Possession</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_possession}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{mc[0]?.home_possession || 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_pass_accuracy}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Pass Accuracy</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_pass_accuracy}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0) > 0 ? (mc[0]?.home_pass_accuracy ?? 0) / ((mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_corners}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Corners</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_corners}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0) > 0 ? (mc[0]?.home_corners ?? 0) / ((mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_yc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Yellow Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_yc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0) > 0 ? (mc[0]?.home_yc ?? 0) / ((mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_rc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Red Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_rc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0) > 0 ? (mc[0]?.home_rc ?? 0) / ((mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_fouls}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Fouls</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_fouls}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0) > 0 ? (mc[0]?.home_fouls ?? 0) / ((mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_saves}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Saves</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_saves}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0) > 0 ? (mc[0]?.home_saves ?? 0) / ((mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_offsides}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Offsides</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_offsides}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0) > 0 ? (mc[0]?.home_offsides ?? 0) / ((mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

</div>
