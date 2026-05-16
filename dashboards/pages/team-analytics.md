---
sidebar: never
hide_toc: true
title: Team Intelligence
---

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

```sql teams
select distinct team_name, team_logo
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and result in ('Win', 'Draw', 'Loss')
order by team_name
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} multiple=true />
{/key}

{#key teams[0]?.team_name}
<Dropdown data={teams} name=team value=team_name label=team_name defaultValue={teams[0]?.team_name} />
{/key}

```sql team_header
select
    team_name,
    team_logo,
    max(coach_name) filter (where coach_name is not null) as coach_name,
    sum(points_earned)::int                              as points,
    count(distinct match_id)::int                        as matches,
    sum(case when result='Win'  then 1 else 0 end)::int  as wins,
    sum(case when result='Draw' then 1 else 0 end)::int  as draws,
    sum(case when result='Loss' then 1 else 0 end)::int  as losses,
    sum(goals_scored)::int                               as gf,
    sum(goals_conceded)::int                             as ga,
    (sum(goals_scored) - sum(goals_conceded))::int       as gd
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name, team_logo
```

```sql team_kpis
with team_curr as (
    select
        round(sum(goals_scored)::double       / count(distinct match_id), 2)  as goals_per_match,
        round(sum(goals_conceded)::double      / count(distinct match_id), 2)  as conceded_per_match,
        round(100.0 * sum(passes_accurate)     / nullif(sum(total_passes), 0), 1) as pass_accuracy,
        round(sum(possession_pct)::double      / count(distinct match_id), 1)  as avg_possession,
        round(100.0 * sum(goals_scored)        / nullif(sum(total_shots), 0), 1) as shot_conv,
        round(sum(yellow_cards)::double        / count(distinct match_id), 2)  as yc_per_match
    from superligaen.mart_match_facts
    where season in ${inputs.season.value}
      and team_name = '${inputs.team.value}'
      and result in ('Win', 'Draw', 'Loss')
),
league_avg as (
    select
        round(sum(goals_scored)::double       / count(distinct match_id), 2)  as league_goals_per_match,
        round(sum(goals_conceded)::double      / count(distinct match_id), 2)  as league_conceded_per_match,
        round(100.0 * sum(passes_accurate)     / nullif(sum(total_passes), 0), 1) as league_pass_accuracy,
        round(100.0 * sum(goals_scored)        / nullif(sum(total_shots), 0), 1) as league_shot_conv,
        round(sum(yellow_cards)::double        / count(distinct match_id), 2)  as league_yc_per_match
    from superligaen.mart_match_facts
    where season in ${inputs.season.value}
      and result in ('Win', 'Draw', 'Loss')
)
select tc.*, la.* from team_curr tc cross join league_avg la
```

```sql all_teams_points
select
    match_round_number  as round,
    team_name,
    cumulative_points,
    case when team_name = '${inputs.team.value}' then 'a_selected' else 'b_others' end as highlight
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and result in ('Win', 'Draw', 'Loss')
order by case when team_name = '${inputs.team.value}' then 0 else 1 end, team_name, match_round_number
```

```sql match_results
select
    match_date,
    match_round_name    as round,
    team_side           as home_away,
    opponent_team_name  as opponent,
    goals_scored        as gf,
    goals_conceded      as ga,
    result,
    points_earned       as pts,
    possession_pct      as possession,
    shots_on_goal,
    total_shots,
    yellow_cards
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql form_last10
select
    match_date,
    result,
    goals_scored   as gf,
    goals_conceded as ga,
    opponent_team_name as opponent
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
limit 10
```

```sql home_away_split
select
    team_side                                                                         as venue,
    count(distinct match_id)::int                                                     as matches,
    sum(case when result='Win'  then 1 else 0 end)::int                              as wins,
    sum(case when result='Draw' then 1 else 0 end)::int                              as draws,
    sum(case when result='Loss' then 1 else 0 end)::int                              as losses,
    sum(points_earned)::int                                                           as points,
    round(sum(goals_scored)::double    / count(distinct match_id), 2)                as goals_per_match,
    round(sum(goals_conceded)::double  / count(distinct match_id), 2)                as conceded_per_match,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)            as pass_accuracy,
    round(sum(possession_pct)::double  / count(distinct match_id), 1)                as avg_possession
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_side
order by team_side desc
```

```sql squad_contributors
select
    player_name,
    player_photo,
    player_position,
    sum(goals_scored)::int                                                            as goals,
    sum(assists)::int                                                                 as assists,
    (sum(goals_scored) + sum(assists))::int                                           as goal_contributions,
    count(distinct match_id)::int                                                     as matches,
    round(avg(rating), 2)                                                             as avg_rating,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)              as goals_per90,
    sum(minutes_played)::int                                                          as minutes
from superligaen.mart_player_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, player_position
having count(distinct match_id) >= 3
order by goal_contributions desc
```

```sql phase_performance
select
    match_round_type                                                                   as phase,
    count(distinct match_id)::int                                                      as matches,
    sum(points_earned)::int                                                            as points,
    sum(goals_scored)::int                                                             as gf,
    sum(goals_conceded)::int                                                           as ga,
    round(sum(goals_scored)::double    / count(distinct match_id), 2)                 as goals_per_match
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by match_round_type
order by matches desc
```

---

## Team Intelligence

{#each team_header as h}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{h.team_logo}" alt="{h.team_name}" class="h-20 w-20 object-contain drop-shadow-xl" onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl md:text-4xl font-extrabold text-white tracking-tight">{h.team_name}</div>
      {#if h.coach_name}
      <div class="text-gray-400 text-sm mt-1">Coach: <span class="text-gray-200 font-semibold">{h.coach_name}</span></div>
      {/if}
      <div class="flex flex-wrap justify-center md:justify-start gap-6 mt-4">
        <div class="text-center"><div class="text-2xl font-black text-white">{h.points}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Points</div></div>
        <div class="text-center"><div class="text-2xl font-black text-green-400">{h.wins}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Wins</div></div>
        <div class="text-center"><div class="text-2xl font-black text-yellow-400">{h.draws}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Draws</div></div>
        <div class="text-center"><div class="text-2xl font-black text-red-400">{h.losses}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Losses</div></div>
        <div class="text-center"><div class="text-2xl font-black text-white">{h.gf}–{h.ga}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Goals</div></div>
        <div class="text-center"><div class="text-2xl font-black {h.gd >= 0 ? 'text-green-400' : 'text-red-400'}">{h.gd > 0 ? '+' : ''}{h.gd}</div><div class="text-xs text-gray-400 uppercase tracking-widest">GD</div></div>
      </div>
    </div>
  </div>
</div>
{/each}

<div class="mb-6">
  <div class="text-sm font-semibold text-gray-500 uppercase tracking-widest mb-3">Last 10 Results</div>
  <div class="flex gap-2 flex-wrap">
    {#each form_last10 as m}
      <div class="relative group">
        <div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-extrabold shadow-md {m.result === 'Win' ? 'bg-green-500 text-white' : m.result === 'Draw' ? 'bg-yellow-400 text-gray-800' : 'bg-red-500 text-white'}">
          {m.result === 'Win' ? 'W' : m.result === 'Draw' ? 'D' : 'L'}
        </div>
        <div class="absolute bottom-11 left-0 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-10 pointer-events-none">
          {m.gf}–{m.ga} vs {m.opponent}
        </div>
      </div>
    {/each}
  </div>
</div>

---

## Performance vs League Average

<div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=goals_per_match title="Goals / Match" comparison=league_goals_per_match comparisonTitle="league avg" comparisonDelta=true />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=conceded_per_match title="Conceded / Match" comparison=league_conceded_per_match comparisonTitle="league avg" comparisonDelta=true downIsGood=true />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=pass_accuracy title="Pass Accuracy %" comparison=league_pass_accuracy comparisonTitle="league avg" comparisonDelta=true fmt='0.0"%"' />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=avg_possession title="Avg Possession %" fmt='0.0"%"' />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=shot_conv title="Shot Conversion %" comparison=league_shot_conv comparisonTitle="league avg" comparisonDelta=true fmt='0.0"%"' />
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center">
    <BigValue data={team_kpis} value=yc_per_match title="YC / Match" comparison=league_yc_per_match comparisonTitle="league avg" comparisonDelta=true downIsGood=true />
  </div>
</div>

---

## Points Race vs The Field

<LineChart
    data={all_teams_points}
    x=round
    y=cumulative_points
    series=highlight
    xAxisTitle="Round"
    yAxisTitle="Points"
    title="{inputs.team.value} vs All Teams — {inputs.season.value}"
    colorPalette={['#3b82f6','#e2e8f0']}
    legend=false
    chartAreaHeight=280
/>

---

## Home vs Away

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={home_away_split}
    x=venue
    y={['wins','draws','losses']}
    title="W/D/L Split"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=grouped
/>

<BarChart
    data={home_away_split}
    x=venue
    y={['goals_per_match','conceded_per_match']}
    title="Goals Scored vs Conceded per Match"
    colorPalette={['#22c55e','#ef4444']}
    type=grouped
/>

<BarChart
    data={home_away_split}
    x=venue
    y=avg_possession
    title="Avg Possession %"
    colorPalette={['#8b5cf6']}
/>

<BarChart
    data={home_away_split}
    x=venue
    y=pass_accuracy
    title="Pass Accuracy %"
    colorPalette={['#0ea5e9']}
/>

</div>

---

## Squad Contributors

<div class="hidden md:block">
<DataTable data={squad_contributors} rows=25>
    <Column id=player_photo       title=""              contentType=image height=32 />
    <Column id=player_name        title="Player"        />
    <Column id=player_position    title="Position"      />
    <Column id=matches            title="MP"            align=center />
    <Column id=goals              title="Goals"         align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists            title="Assists"       align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=goal_contributions title="G+A"           align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=goals_per90        title="G/90"          contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=avg_rating         title="Rating"        contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=minutes            title="Minutes"       align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={squad_contributors} rows=20>
    <Column id=player_name        title="Player"  />
    <Column id=goals              title="G"       align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists            title="A"       align=center />
    <Column id=goal_contributions title="G+A"    align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=avg_rating         title="Rating"  />
</DataTable>
</div>

---

## Phase Performance

{#if phase_performance.length > 1}
<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={phase_performance}
    x=phase
    y=points
    title="Points by Phase"
    colorPalette={['#3b82f6']}
/>

<BarChart
    data={phase_performance}
    x=phase
    y=goals_per_match
    title="Goals per Match by Phase"
    colorPalette={['#22c55e']}
/>

</div>
{/if}

---

## Match Log

<div class="hidden md:block">
<DataTable data={match_results} rows=20>
    <Column id=match_date    title="Date"       />
    <Column id=round         title="Round"      />
    <Column id=home_away     title="H/A"        align=center />
    <Column id=opponent      title="Opponent"   />
    <Column id=gf            title="GF"         align=center />
    <Column id=ga            title="GA"         align=center />
    <Column id=result        title="Result"     contentType=colorscale colorPalette={['#ef4444','#eab308','#22c55e']} />
    <Column id=pts           title="Pts"        align=center />
    <Column id=possession    title="Poss %"     fmt='0.0"%"' />
    <Column id=shots_on_goal title="SoG"        align=center />
    <Column id=yellow_cards  title="YC"         align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={match_results} rows=20>
    <Column id=match_date title="Date"     />
    <Column id=opponent   title="Opponent" />
    <Column id=gf         title="GF"      align=center />
    <Column id=ga         title="GA"      align=center />
    <Column id=result     title="Result"  />
</DataTable>
</div>
