---
sidebar: never
hide_toc: true
title: Match Results
---

<script>
  import MatchLineup from '../../components/MatchLineup.svelte';
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  group by season
) order by is_current desc, season desc
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

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
    sum(total_shots)                as total_shots,
    sum(big_chances_created)        as total_big_chances,
    sum(yellow_cards)               as total_yellow_cards,
    sum(red_cards)                  as total_red_cards,
    referee_name                    as referee,
    season
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) in ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_id, match_date, match_round_name, match_round_number, match_name, match_short_name, score, referee_name, season
order by match_date desc
```

```sql round_kpis
select
    sum(total_goals)                                                                        as total_goals,
    round(sum(total_goals)::double / count(distinct match_id), 2)                          as avg_goals_per_match,
    round(sum(total_shots_on_goal)::double / count(distinct match_id), 1)                  as avg_shots_on_goal,
    round(sum(total_goals)::double / nullif(sum(total_big_chances), 0), 2)                   as goals_per_big_chance
from ${results}
```

## Match Results — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_goals          title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_goals_per_match   title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_shots_on_goal     title="Avg Shots on Goal"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=goals_per_big_chance   title="Goals / Big Chance"  fmt="0.00" /></div>
</div>

<div class="block md:hidden">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_short_name    title="Match"          wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Ch."        contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=round               title="Round"          />
    <Column id=match_name          title="Match"          wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Chances"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>

---

## Match Analysis

```sql match_options
select
    match_name || '|' || cast(match_date as varchar) as match_key,
    match_short_name || '  (' || score || ')'        as match_label,
    match_date
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) in ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_name, match_short_name, match_date, score
order by match_date desc
```

{#key match_options[0]?.match_key}
<Dropdown data={match_options} name=match value=match_key label=match_label defaultValue={match_options[0]?.match_key} order="match_date desc" />
{/key}

```sql mc
select
    max(case when team_side = 'Home' then team_name end)                         as home_team,
    max(case when team_side = 'Away' then team_name end)                         as away_team,
    max(case when team_side = 'Home' then team_short_name end)                   as home_team_short,
    max(case when team_side = 'Away' then team_short_name end)                   as away_team_short,
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
    max(case when team_side = 'Away' then saves end)                             as away_saves,
    max(case when team_side = 'Home' then total_shots end)                       as home_total_shots,
    max(case when team_side = 'Away' then total_shots end)                       as away_total_shots,
    max(case when team_side = 'Home' then big_chances_created end)               as home_big_chances,
    max(case when team_side = 'Away' then big_chances_created end)               as away_big_chances,
    max(case when team_side = 'Home' then tackles end)                           as home_tackles,
    max(case when team_side = 'Away' then tackles end)                           as away_tackles,
    max(case when team_side = 'Home' then woodwork_hits end)                     as home_woodwork,
    max(case when team_side = 'Away' then woodwork_hits end)                     as away_woodwork
from superligaen.mart_match_facts
where match_name            = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and season                = '${inputs.season.value}'
```

<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2">

  <div class="grid grid-cols-3 text-center border-b border-gray-200 pb-4 mb-2">
    <div class="text-left font-bold text-lg text-blue-600">{mc[0]?.home_team_short}<div class="text-xs font-normal text-gray-400">Home</div></div>
    <div class="text-center text-2xl font-bold text-gray-700">{mc[0]?.score}</div>
    <div class="text-right font-bold text-lg text-orange-500">{mc[0]?.away_team_short}<div class="text-xs font-normal text-gray-400">Away</div></div>
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
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_total_shots}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Total Shots</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_total_shots}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_total_shots ?? 0) + (mc[0]?.away_total_shots ?? 0) > 0 ? (mc[0]?.home_total_shots ?? 0) / ((mc[0]?.home_total_shots ?? 0) + (mc[0]?.away_total_shots ?? 0)) * 100 : 50}%"></div>
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
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_big_chances}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Big Chances</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_big_chances}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_big_chances ?? 0) + (mc[0]?.away_big_chances ?? 0) > 0 ? (mc[0]?.home_big_chances ?? 0) / ((mc[0]?.home_big_chances ?? 0) + (mc[0]?.away_big_chances ?? 0)) * 100 : 50}%"></div>
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

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_tackles}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Tackles</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_tackles}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_tackles ?? 0) + (mc[0]?.away_tackles ?? 0) > 0 ? (mc[0]?.home_tackles ?? 0) / ((mc[0]?.home_tackles ?? 0) + (mc[0]?.away_tackles ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_offsides}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Offsides</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_offsides}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0) > 0 ? (mc[0]?.home_offsides ?? 0) / ((mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_woodwork}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Woodwork Hits</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_woodwork}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_woodwork ?? 0) + (mc[0]?.away_woodwork ?? 0) > 0 ? (mc[0]?.home_woodwork ?? 0) / ((mc[0]?.home_woodwork ?? 0) + (mc[0]?.away_woodwork ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

</div>

---

## Lineup

```sql lineup
select
    player_name,
    player_photo,
    team_name,
    team_logo,
    team_side,
    position_group,
    position_name,
    position_short_code,
    formation,
    minutes_played,
    goals_scored,
    assists,
    shots_total,
    shots_on_target,
    key_passes,
    big_chances_created,
    dribbles_completed,
    tackles,
    interceptions,
    clearances,
    aerials_won,
    blocks,
    fouls_committed,
    saves,
    yellow_cards,
    red_cards,
    round(rating, 2) as rating
from superligaen.mart_player_facts
where match_name                 = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Starter'
order by team_side desc, position_group, position_name
```

```sql subs
select
    player_name,
    player_photo,
    team_name,
    team_side,
    position_group,
    position_name,
    position_short_code,
    formation,
    round(rating, 2) as rating
from superligaen.mart_player_facts
where match_name                 = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Substitute'
order by team_side desc, position_group, position_name
```

<MatchLineup {lineup} {subs} home_team={mc[0]?.home_team} away_team={mc[0]?.away_team} />
