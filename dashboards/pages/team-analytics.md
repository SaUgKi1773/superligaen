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
        round(sum(goals_scored)::double       / count(*), 2)  as league_goals_per_match,
        round(sum(goals_conceded)::double      / count(*), 2)  as league_conceded_per_match,
        round(100.0 * sum(passes_accurate)     / nullif(sum(total_passes), 0), 1) as league_pass_accuracy,
        round(100.0 * sum(goals_scored)        / nullif(sum(total_shots), 0), 1) as league_shot_conv,
        round(sum(yellow_cards)::double        / count(*), 2)  as league_yc_per_match
    from superligaen.mart_match_facts
    where season in ${inputs.season.value}
      and result in ('Win', 'Draw', 'Loss')
)
select
    tc.*,
    la.*,
    round(tc.goals_per_match     / nullif(la.league_goals_per_match,     0), 2) as goals_ratio,
    round(tc.conceded_per_match  / nullif(la.league_conceded_per_match,  0), 2) as conceded_ratio,
    round(tc.pass_accuracy       / nullif(la.league_pass_accuracy,       0), 2) as pass_ratio,
    round(tc.shot_conv           / nullif(la.league_shot_conv,           0), 2) as shot_conv_ratio,
    round(tc.yc_per_match        / nullif(la.league_yc_per_match,        0), 2) as yc_ratio
from team_curr tc cross join league_avg la
```

```sql all_teams_points
select
    match_round_number  as round,
    team_name,
    cumulative_points,
    case when team_name = '${inputs.team.value}' then '${inputs.team.value}' else 'Other Teams' end as highlight
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
    case result
        when 'Win'  then '<span style="background:#22c55e;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="background:#eab308;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">D</span>'
        when 'Loss' then '<span style="background:#ef4444;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">L</span>'
    end as result_badge,
    points_earned       as pts,
    possession_pct                                                        as possession,
    shots_on_goal,
    total_shots,
    round(100.0 * passes_accurate / nullif(total_passes, 0), 1)           as pass_accuracy,
    round(100.0 * goals_scored    / nullif(total_shots,   0), 1)           as shot_conv,
    yellow_cards
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql form_last10
select * from (
    select
        match_date,
        result,
        goals_scored       as gf,
        goals_conceded     as ga,
        opponent_team_name as opponent
    from superligaen.mart_match_facts
    where season in ${inputs.season.value}
      and team_name = '${inputs.team.value}'
      and result in ('Win', 'Draw', 'Loss')
    order by match_date desc
    limit 10
) order by match_date asc
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
    '<img src="' || player_photo || '" style="height:72px;width:72px;object-fit:cover;border-radius:50%;" onerror="this.style.display=''none''">' as player_photo,
    player_position,
    sum(goals_scored)::int                                                            as goals,
    sum(assists)::int                                                                 as assists,
    (sum(goals_scored) + sum(assists))::int                                           as goal_contributions,
    count(distinct match_id)::int                                                     as matches,
    round(avg(rating), 2)                                                             as avg_rating,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)              as goals_per90,
    round((sum(goals_scored) + sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2) as contributions_per90,
    -- attack
    sum(shots_total)::int                                                                        as shots,
    round(sum(shots_total) * 90.0 / nullif(sum(minutes_played), 0), 2)                          as shots_per90,
    sum(shots_on_target)::int                                                                    as shots_on_target,
    sum(big_chances_created)::int                                                                as big_chances_created,
    -- passing
    sum(key_passes)::int                                                                         as key_passes,
    round(sum(key_passes) * 90.0 / nullif(sum(minutes_played), 0), 2)                           as key_passes_per90,
    sum(chances_created)::int                                                                    as chances_created,
    round(sum(chances_created) * 90.0 / nullif(sum(minutes_played), 0), 2)                      as chances_created_per90,
    sum(passes_total)::int                                                                       as passes,
    round(100.0 * sum(passes_accurate) / nullif(sum(passes_total), 0), 1)                       as pass_accuracy,
    sum(crosses_total)::int                                                                      as crosses,
    round(sum(crosses_total) * 90.0 / nullif(sum(minutes_played), 0), 2)                        as crosses_per90,
    round(100.0 * sum(crosses_accurate) / nullif(sum(crosses_total), 0), 1)                     as cross_accuracy,
    -- defense
    sum(tackles)::int                                                                            as tackles,
    round(sum(tackles) * 90.0 / nullif(sum(minutes_played), 0), 2)                              as tackles_per90,
    sum(interceptions)::int                                                                      as interceptions,
    round(sum(interceptions) * 90.0 / nullif(sum(minutes_played), 0), 2)                        as interceptions_per90,
    sum(clearances)::int                                                                         as clearances,
    sum(aerials_won)::int                                                                        as aerials_won,
    -- dribbling
    sum(dribbles_completed)::int                                                                 as dribbles,
    round(sum(dribbles_completed) * 90.0 / nullif(sum(minutes_played), 0), 2)                   as dribbles_per90,
    round(100.0 * sum(dribbles_completed) / nullif(sum(dribbles_attempts), 0), 1)               as dribble_success_pct,
    -- discipline
    sum(yellow_cards)::int                                                                       as yellow_cards,
    sum(red_cards)::int                                                                          as red_cards,
    sum(fouls_committed)::int                                                                    as fouls,
    sum(fouls_drawn)::int                                                                        as fouls_drawn,
    -- general
    sum(minutes_played)::int                                                                     as minutes
from superligaen.mart_player_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, player_position
having count(distinct match_id) >= 3
order by avg_rating desc nulls last
```

```sql attack_metrics
select value, label from (values
    ('goals', 'Goals'), ('assists', 'Assists'), ('goal_contributions', 'G+A'),
    ('goals_per90', 'G/90'), ('contributions_per90', 'G+A/90'),
    ('shots', 'Shots'), ('shots_per90', 'Shots/90'),
    ('shots_on_target', 'Shots on Target'), ('big_chances_created', 'Big Chances')
) t(value, label)
```

```sql passing_metrics
select value, label from (values
    ('key_passes', 'Key Passes'), ('key_passes_per90', 'Key Passes/90'),
    ('chances_created', 'Chances Created'), ('chances_created_per90', 'Chances/90'),
    ('passes', 'Passes'), ('pass_accuracy', 'Pass Acc %'),
    ('crosses', 'Crosses'), ('crosses_per90', 'Crosses/90'), ('cross_accuracy', 'Cross Acc %')
) t(value, label)
```

```sql defense_metrics
select value, label from (values
    ('tackles', 'Tackles'), ('tackles_per90', 'Tackles/90'),
    ('interceptions', 'Interceptions'), ('interceptions_per90', 'Interceptions/90'),
    ('clearances', 'Clearances'), ('aerials_won', 'Aerials Won')
) t(value, label)
```

```sql dribbling_metrics
select value, label from (values
    ('dribbles', 'Dribbles'), ('dribbles_per90', 'Dribbles/90'),
    ('dribble_success_pct', 'Dribble Success %')
) t(value, label)
```

```sql discipline_metrics
select value, label from (values
    ('yellow_cards', 'Yellow Cards'), ('red_cards', 'Red Cards'),
    ('fouls', 'Fouls'), ('fouls_drawn', 'Fouls Drawn')
) t(value, label)
```

```sql phase_performance
select
    match_round_type                                                                   as phase,
    count(distinct match_id)::int                                                      as matches,
    sum(points_earned)::int                                                            as points,
    round(sum(points_earned)::double / count(distinct match_id), 2)                   as points_per_match,
    sum(goals_scored)::int                                                             as gf,
    sum(goals_conceded)::int                                                           as ga,
    round(sum(goals_scored)::double    / count(distinct match_id), 2)                 as goals_per_match
from superligaen.mart_match_facts
where season in ${inputs.season.value}
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
group by match_round_type
order by case match_round_type
    when 'Regular Season'       then 1
    when 'Championship Group'   then 2
    when 'Relegation Group'     then 2
    else 3
end
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

{#each team_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals Scored / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">League avg: {k.league_goals_per_match}</span>
      <span class="text-sm font-bold {k.goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.goals_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals Conceded / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.conceded_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">League avg: {k.league_conceded_per_match}</span>
      <span class="text-sm font-bold {k.conceded_ratio <= 1 ? 'text-green-600' : 'text-red-500'}">{k.conceded_ratio <= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.pass_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">League avg: {k.league_pass_accuracy}%</span>
      <span class="text-sm font-bold {k.pass_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.pass_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Avg Possession %</div>
    <div class="text-3xl font-black text-center flex-1 flex items-center justify-center {k.avg_possession >= 55 ? 'text-green-600' : k.avg_possession < 45 ? 'text-red-500' : 'text-orange-400'}">{k.avg_possession}%</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Conversion %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_conv}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">League avg: {k.league_shot_conv}%</span>
      <span class="text-sm font-bold {k.shot_conv_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.shot_conv_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">YC / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.yc_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">League avg: {k.league_yc_per_match}</span>
      <span class="text-sm font-bold {k.yc_ratio <= 1 ? 'text-green-600' : 'text-red-500'}">{k.yc_ratio <= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

</div>
{/each}

---

## Points Race

<div style="pointer-events: none;">
<LineChart
    data={all_teams_points}
    x=round
    y=cumulative_points
    series=highlight
    xAxisTitle="Round"
    yAxisTitle="Points"
    title=""
    colorPalette={['#3b82f6','#e2e8f0']}
    legend=false
    chartAreaHeight=280
/>
</div>

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
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y={['goals_per_match','conceded_per_match']}
    title="Goals Scored vs Conceded per Match"
    colorPalette={['#22c55e','#ef4444']}
    type=grouped
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y=avg_possession
    title="Avg Possession %"
    colorPalette={['#8b5cf6']}
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y=pass_accuracy
    title="Pass Accuracy %"
    colorPalette={['#0ea5e9']}
    sort=false
/>

</div>

---

## Squad Contributors

<div class="grid grid-cols-2 md:grid-cols-5 gap-2 mb-4">
  <Dropdown data={attack_metrics}    name=attack_cols    value=value label=label defaultValue={[]} multiple=true title="Attack" />
  <Dropdown data={passing_metrics}   name=passing_cols   value=value label=label defaultValue={[]} multiple=true title="Passing" />
  <Dropdown data={defense_metrics}   name=defense_cols   value=value label=label defaultValue={[]} multiple=true title="Defense" />
  <Dropdown data={dribbling_metrics} name=dribbling_cols value=value label=label defaultValue={[]} multiple=true title="Dribbling" />
  <Dropdown data={discipline_metrics} name=discipline_cols value=value label=label defaultValue={[]} multiple=true title="Discipline" />
</div>

<div class="hidden md:block">
<DataTable data={squad_contributors} rows=10>
    <Column id=player_photo             title=""               contentType=html />
    <Column id=player_name              title="Player"         />
    <Column id=player_position          title="Pos"            />
    <Column id=matches                  title="MP"             align=center />
    <Column id=minutes                  title="Minutes"        align=center />
    <Column id=avg_rating               title="Rating"         contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {#if inputs.attack_cols.value?.includes('goals')}
    <Column id=goals                    title="Goals"          align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('assists')}
    <Column id=assists                  title="Assists"        align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('goal_contributions')}
    <Column id=goal_contributions       title="G+A"            align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('contributions_per90')}
    <Column id=contributions_per90      title="G+A/90"         contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('goals_per90')}
    <Column id=goals_per90              title="G/90"           contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots')}
    <Column id=shots                    title="Shots"          align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots_per90')}
    <Column id=shots_per90              title="Shots/90"       contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots_on_target')}
    <Column id=shots_on_target          title="SoT"            align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('big_chances_created')}
    <Column id=big_chances_created      title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('key_passes')}
    <Column id=key_passes               title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('key_passes_per90')}
    <Column id=key_passes_per90         title="Key Passes/90"  contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('chances_created')}
    <Column id=chances_created          title="Chances"        align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('chances_created_per90')}
    <Column id=chances_created_per90    title="Chances/90"     contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('passes')}
    <Column id=passes                   title="Passes"         align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('pass_accuracy')}
    <Column id=pass_accuracy            title="Pass Acc %"     fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('crosses')}
    <Column id=crosses                  title="Crosses"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('crosses_per90')}
    <Column id=crosses_per90            title="Crosses/90"     contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('cross_accuracy')}
    <Column id=cross_accuracy           title="Cross Acc %"    fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('tackles')}
    <Column id=tackles                  title="Tackles"        align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('tackles_per90')}
    <Column id=tackles_per90            title="Tackles/90"     contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('interceptions')}
    <Column id=interceptions            title="Interceptions"  align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('interceptions_per90')}
    <Column id=interceptions_per90      title="Interceptions/90" contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('clearances')}
    <Column id=clearances               title="Clearances"     align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('aerials_won')}
    <Column id=aerials_won              title="Aerials Won"    align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribbles')}
    <Column id=dribbles                 title="Dribbles"       align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribbles_per90')}
    <Column id=dribbles_per90           title="Dribbles/90"    contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribble_success_pct')}
    <Column id=dribble_success_pct      title="Dribble Success %" fmt='0.0"%"' contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('yellow_cards')}
    <Column id=yellow_cards             title="YC"             align=center contentType=colorscale colorPalette={['white','#eab308']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('red_cards')}
    <Column id=red_cards                title="RC"             align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('fouls')}
    <Column id=fouls                    title="Fouls"          align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn              title="Fouls Drawn"    align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={squad_contributors} rows=10>
    <Column id=player_name              title="Player"         />
    <Column id=player_position          title="Pos"            />
    <Column id=matches                  title="MP"             align=center />
    <Column id=minutes                  title="Minutes"        align=center />
    <Column id=avg_rating               title="Rating"         contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {#if inputs.attack_cols.value?.includes('goals')}
    <Column id=goals                    title="Goals"          align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('assists')}
    <Column id=assists                  title="Assists"        align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('goal_contributions')}
    <Column id=goal_contributions       title="G+A"            align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('contributions_per90')}
    <Column id=contributions_per90      title="G+A/90"         contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('goals_per90')}
    <Column id=goals_per90              title="G/90"           contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots')}
    <Column id=shots                    title="Shots"          align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots_per90')}
    <Column id=shots_per90              title="Shots/90"       contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('shots_on_target')}
    <Column id=shots_on_target          title="SoT"            align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    {/if}
    {#if inputs.attack_cols.value?.includes('big_chances_created')}
    <Column id=big_chances_created      title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('key_passes')}
    <Column id=key_passes               title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('key_passes_per90')}
    <Column id=key_passes_per90         title="Key Passes/90"  contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('chances_created')}
    <Column id=chances_created          title="Chances"        align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('chances_created_per90')}
    <Column id=chances_created_per90    title="Chances/90"     contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('passes')}
    <Column id=passes                   title="Passes"         align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('pass_accuracy')}
    <Column id=pass_accuracy            title="Pass Acc %"     fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('crosses')}
    <Column id=crosses                  title="Crosses"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('crosses_per90')}
    <Column id=crosses_per90            title="Crosses/90"     contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.passing_cols.value?.includes('cross_accuracy')}
    <Column id=cross_accuracy           title="Cross Acc %"    fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('tackles')}
    <Column id=tackles                  title="Tackles"        align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('tackles_per90')}
    <Column id=tackles_per90            title="Tackles/90"     contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('interceptions')}
    <Column id=interceptions            title="Interceptions"  align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('interceptions_per90')}
    <Column id=interceptions_per90      title="Interceptions/90" contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('clearances')}
    <Column id=clearances               title="Clearances"     align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.defense_cols.value?.includes('aerials_won')}
    <Column id=aerials_won              title="Aerials Won"    align=center contentType=colorscale colorPalette={['white','#22c55e']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribbles')}
    <Column id=dribbles                 title="Dribbles"       align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribbles_per90')}
    <Column id=dribbles_per90           title="Dribbles/90"    contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.dribbling_cols.value?.includes('dribble_success_pct')}
    <Column id=dribble_success_pct      title="Dribble Success %" fmt='0.0"%"' contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('yellow_cards')}
    <Column id=yellow_cards             title="YC"             align=center contentType=colorscale colorPalette={['white','#eab308']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('red_cards')}
    <Column id=red_cards                title="RC"             align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('fouls')}
    <Column id=fouls                    title="Fouls"          align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.discipline_cols.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn              title="Fouls Drawn"    align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
</DataTable>
</div>

---

## Phase Performance

{#if phase_performance.length > 1}
<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={phase_performance}
    x=phase
    y=points_per_match
    title="Points per Match by Phase"
    yAxisTitle="Pts / Match"
    colorPalette={['#3b82f6']}
    sort=false
/>

<BarChart
    data={phase_performance}
    x=phase
    y=goals_per_match
    title="Goals per Match by Phase"
    colorPalette={['#22c55e']}
    sort=false
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
    <Column id=result_badge  title="Result"     contentType=html align=center />
    <Column id=pts           title="Pts"        align=center />
    <Column id=possession    title="Poss %"     fmt='0.0"%"' align=center />
    <Column id=pass_accuracy title="Pass Acc %" fmt='0.0"%"' align=center />
    <Column id=shots_on_goal title="SoG"        align=center />
    <Column id=shot_conv     title="Shot Conv %" fmt='0.0"%"' align=center />
    <Column id=yellow_cards  title="YC"         align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={match_results} rows=20>
    <Column id=match_date    title="Date"       />
    <Column id=opponent      title="Opponent"   />
    <Column id=gf            title="GF"         align=center />
    <Column id=ga            title="GA"         align=center />
    <Column id=result_badge  title="Result"     contentType=html align=center />
    <Column id=pts           title="Pts"        align=center />
    <Column id=possession    title="Poss %"     fmt='0.0"%"' align=center />
    <Column id=pass_accuracy title="Pass Acc %" fmt='0.0"%"' align=center />
    <Column id=shots_on_goal title="SoG"        align=center />
    <Column id=shot_conv     title="Shot Conv %" fmt='0.0"%"' align=center />
    <Column id=yellow_cards  title="YC"         align=center />
</DataTable>
</div>
