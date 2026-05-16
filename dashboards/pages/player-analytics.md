---
sidebar: never
hide_toc: true
title: Player Intelligence
---

<script>
  import TeamRadar from '../../components/TeamRadar.svelte';

  const playerMetrics = [
    { key: 'goals_per90_pct',   label: 'Attack Score'     },
    { key: 'assists_per90_pct', label: 'Creativity Score' },
    { key: 'pass_pct',          label: 'Passing Score'    },
    { key: 'shot_conv_pct',     label: 'Efficiency Score' },
    { key: 'rating_pct',        label: 'Overall Score'    },
    { key: 'defense_pct',       label: 'Defensive Score'  },
  ];
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_player_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

```sql teams
select distinct team_name
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by team_name
```

```sql positions
select distinct player_position
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ('Win', 'Draw', 'Loss')
  and player_position is not null
order by player_position
```

```sql players_in_team
select distinct player_name
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and player_position in ${inputs.position.value}
  and result in ('Win', 'Draw', 'Loss')
order by player_name
```


```sql top_players
with base as (
    select
        player_name,
        player_photo,
        player_position,
        count(distinct match_id)                        as matches,
        sum(goals_scored)                               as goals,
        sum(assists)                                    as assists,
        sum(dribbles_completed)                         as dribbles,
        sum(tackles) + sum(interceptions)               as defensive_actions,
        sum(crosses_total)                              as crosses,
        sum(passes_accurate)                            as passes
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and team_name = '${inputs.team.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, player_position
    having count(distinct match_id) >= 3
)
select category, player_name, player_photo, player_position, stat_value, stat_label
from (
    select 'Top Scorer'   as category, player_name, player_photo, player_position, goals::int             as stat_value, 'Goals'        as stat_label, row_number() over (order by goals             desc) as rn from base
    union all
    select 'Top Assister',              player_name, player_photo, player_position, assists::int,              'Assists',      row_number() over (order by assists           desc) from base
    union all
    select 'Top Dribbler',              player_name, player_photo, player_position, dribbles::int,             'Dribbles',     row_number() over (order by dribbles          desc) from base
    union all
    select 'Top Defender',              player_name, player_photo, player_position, defensive_actions::int,    'Tkl+Int',      row_number() over (order by defensive_actions desc) from base
    union all
    select 'Top Crosser',               player_name, player_photo, player_position, crosses::int,              'Crosses',      row_number() over (order by crosses           desc) from base
    union all
    select 'Top Passer',                player_name, player_photo, player_position, passes::int,               'Acc. Passes',  row_number() over (order by passes            desc) from base
)
where rn = 1
order by case category
    when 'Top Scorer'   then 1
    when 'Top Assister' then 2
    when 'Top Dribbler' then 3
    when 'Top Defender' then 4
    when 'Top Crosser'  then 5
    when 'Top Passer'   then 6
end
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key teams[0]?.team_name}
<Dropdown data={teams} name=team value=team_name label=team_name defaultValue={teams[0]?.team_name} />
{/key}

```sql player_profile
select
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    count(distinct match_id)::int                                                         as matches,
    sum(minutes_played)::int                                                              as minutes,
    sum(goals_scored)::int                                                                as goals,
    sum(assists)::int                                                                     as assists,
    sum(shots_total)::int                                                                 as shots,
    sum(shots_on_target)::int                                                             as shots_on_target,
    sum(key_passes)::int                                                                  as key_passes,
    sum(tackles)::int                                                                     as tackles,
    sum(yellow_cards)::int                                                                as yellow_cards,
    round(avg(rating), 2)                                                                 as avg_rating,
    round(sum(goals_scored)  * 90.0 / nullif(sum(minutes_played), 0), 2)                 as goals_per90,
    round(sum(assists)       * 90.0 / nullif(sum(minutes_played), 0), 2)                 as assists_per90,
    round((sum(goals_scored) + sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2) as contributions_per90,
    round(100.0 * sum(passes_accurate)  / nullif(sum(passes_total), 0), 1)               as pass_accuracy,
    round(100.0 * sum(goals_scored)     / nullif(sum(shots_total),  0), 1)               as shot_conversion,
    sum(case when result = 'Win'  then 1 else 0 end)::int                                as wins,
    sum(case when result = 'Draw' then 1 else 0 end)::int                                as draws,
    sum(case when result = 'Loss' then 1 else 0 end)::int                                as losses
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, team_name, team_logo, player_position
```

```sql player_trend
select
    match_round_number                             as round,
    goals_scored                                   as goals,
    assists,
    rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_round_number
```

```sql player_match_log
select
    strftime(match_date, '%Y-%m-%d')              as match_date,
    match_round_name                              as round,
    opponent_team_name                            as opponent,
    team_side                                     as home_away,
    case result
        when 'Win'  then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#22c55e;color:white;border-radius:4px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#eab308;color:white;border-radius:4px;font-size:12px;font-weight:700;">D</span>'
        else             '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#ef4444;color:white;border-radius:4px;font-size:12px;font-weight:700;">L</span>'
    end                                           as result_badge,
    minutes_played,
    goals_scored                                  as goals,
    assists,
    shots_total                                   as shots,
    shots_on_target,
    key_passes,
    tackles,
    yellow_cards,
    rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql league_context
with base as (
    select
        player_name,
        sum(goals_scored)                                                          as goals,
        sum(assists)                                                               as assists,
        avg(rating)                                                                as avg_rating,
        sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0)                 as goals_per90,
        sum(assists)      * 90.0 / nullif(sum(minutes_played), 0)                 as assists_per90,
        100.0 * sum(passes_accurate) / nullif(sum(passes_total),  0)              as pass_accuracy,
        100.0 * sum(goals_scored)    / nullif(sum(shots_total),   0)              as shot_conversion,
        sum(tackles)      * 90.0 / nullif(sum(minutes_played), 0)                 as tackles_per90
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by player_name
    having sum(minutes_played) >= 450
),
ranked as (
    select
        player_name,
        round(percent_rank() over (order by goals)           * 100) as goals_pct,
        round(percent_rank() over (order by assists)         * 100) as assists_pct,
        round(percent_rank() over (order by avg_rating)      * 100) as rating_pct,
        round(percent_rank() over (order by goals_per90)     * 100) as goals_per90_pct,
        round(percent_rank() over (order by assists_per90)   * 100) as assists_per90_pct,
        round(percent_rank() over (order by pass_accuracy)   * 100) as pass_pct,
        round(percent_rank() over (order by shot_conversion) * 100) as shot_conv_pct,
        round(percent_rank() over (order by tackles_per90)   * 100) as defense_pct
    from base
)
select * from ranked where player_name = '${inputs.player.value}'
```

---

## Team Leaders

<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
{#each top_players as tp}
<div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col items-center text-center">
  <div class="text-xs font-semibold text-gray-500 uppercase tracking-widest mb-3">{tp.category}</div>
  <img src="{tp.player_photo}" alt="{tp.player_name}" class="h-16 w-16 rounded-full object-cover mb-3 border-2 border-gray-100" onerror="this.style.display='none'" />
  <div class="text-sm font-bold text-gray-900 leading-tight">{tp.player_name}</div>
  <div class="text-xs text-gray-400 mt-1">{tp.player_position}</div>
  <div class="mt-3 text-2xl font-black text-blue-600">{tp.stat_value}</div>
  <div class="text-xs text-gray-400">{tp.stat_label}</div>
</div>
{/each}
</div>

---

## Player Deep Dive

{#key positions.map(p => p.player_position).join(',')}
<Dropdown data={positions} name=position value=player_position label=player_position multiple=true defaultValue={positions.map(p => p.player_position)} />
{/key}

{#key players_in_team[0]?.player_name}
<Dropdown data={players_in_team} name=player value=player_name label=player_name defaultValue={players_in_team[0]?.player_name} />
{/key}

## Player Profile

{#each player_profile as p}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{p.player_photo}" alt="{p.player_name}"
      class="h-28 w-28 rounded-full object-cover border-4 border-white/20 shadow-xl flex-shrink-0"
      onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl md:text-4xl font-extrabold text-white leading-tight">{p.player_name}</div>
      <div class="flex items-center justify-center md:justify-start gap-2 mt-2">
        <img src="{p.team_logo}" alt="{p.team_name}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
        <span class="text-gray-300 text-sm">{p.team_name}</span>
        <span class="text-gray-500 text-sm">·</span>
        <span class="text-gray-400 text-sm">{p.player_position}</span>
      </div>
      <div class="flex flex-wrap justify-center md:justify-start gap-6 mt-6">
        <div class="text-center">
          <div class="text-3xl font-black text-amber-400">{p.goals}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Goals</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-black text-blue-400">{p.assists}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Assists</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-black text-purple-400">{p.avg_rating ?? '—'}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Avg Rating</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-black text-white">{p.matches}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Apps</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-black text-green-400">{p.goals_per90}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">G/90</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-black text-teal-400">{p.contributions_per90}</div>
          <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">G+A/90</div>
        </div>
      </div>
      <div class="flex justify-center md:justify-start gap-3 mt-5">
        <span class="px-3 py-1 rounded-full bg-green-500/20 text-green-400 text-sm font-bold">{p.wins}W</span>
        <span class="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-sm font-bold">{p.draws}D</span>
        <span class="px-3 py-1 rounded-full bg-red-500/20 text-red-400 text-sm font-bold">{p.losses}L</span>
        <span class="px-3 py-1 rounded-full bg-gray-500/20 text-gray-400 text-sm">{p.minutes} mins</span>
      </div>
    </div>
  </div>
</div>
{/each}

---

## Season Overview

{#each player_profile as p}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals</div>
    <div class="text-3xl font-black text-center text-amber-500 flex-1 flex items-center justify-center">{p.goals}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} shots · {p.shots_on_target} on target</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Assists</div>
    <div class="text-3xl font-black text-center text-blue-500 flex-1 flex items-center justify-center">{p.assists}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.key_passes} key passes</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals / 90</div>
    <div class="text-3xl font-black text-center text-green-600 flex-1 flex items-center justify-center">{p.goals_per90}</div>
    <div class="text-xs text-gray-400 text-center mt-3">G+A/90: {p.contributions_per90}</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Assists / 90</div>
    <div class="text-3xl font-black text-center text-blue-600 flex-1 flex items-center justify-center">{p.assists_per90}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.matches} appearances</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy</div>
    <div class="text-3xl font-black text-center text-purple-600 flex-1 flex items-center justify-center">{p.pass_accuracy}%</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.minutes} minutes played</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Conversion</div>
    <div class="text-3xl font-black text-center text-orange-500 flex-1 flex items-center justify-center">{p.shot_conversion != null ? p.shot_conversion + '%' : '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} total shots</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Avg Rating</div>
    <div class="text-3xl font-black text-center text-violet-600 flex-1 flex items-center justify-center">{p.avg_rating ?? '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.matches} appearances</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Minutes Played</div>
    <div class="text-3xl font-black text-center text-gray-700 flex-1 flex items-center justify-center">{p.minutes}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.tackles} tackles · {p.yellow_cards} YC</div>
  </div>

</div>
{/each}

---

## League Standing

*Percentile rank among all players with 450+ minutes in {inputs.season.value}. 100 = best in the league.*

{#each league_context as lc}
<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-center">

  <div class="flex flex-col gap-3">

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Goals / 90</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-amber-400" style="width:{lc.goals_per90_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.goals_per90_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Assists / 90</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-sky-400" style="width:{lc.assists_per90_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.assists_per90_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Pass Accuracy</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-indigo-500" style="width:{lc.pass_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.pass_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Shot Conversion</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-orange-400" style="width:{lc.shot_conv_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.shot_conv_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Avg Rating</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-violet-500" style="width:{lc.rating_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.rating_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Defensive</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-teal-500" style="width:{lc.defense_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.defense_pct}</div>
    </div>

  </div>

  <TeamRadar data={league_context} metrics={playerMetrics} />

</div>
{/each}

---

## Performance Timeline

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<LineChart
    data={player_trend}
    x=round
    y=rating
    xAxisTitle="Round"
    yAxisTitle="Match Rating"
    title="Rating per Match"
    lineColor="#8b5cf6"
    chartAreaHeight=220
/>

<BarChart
    data={player_trend}
    x=round
    y={['goals','assists']}
    xAxisTitle="Round"
    yAxisTitle="Contributions"
    title="Goals & Assists per Match"
    colorPalette={['#f59e0b','#3b82f6']}
    chartAreaHeight=220
    stacked=true
/>

</div>

---

## Match Log

<div class="hidden md:block">
<DataTable data={player_match_log} rows=20>
    <Column id=match_date      title="Date"     />
    <Column id=round           title="Round"    />
    <Column id=home_away       title="H/A"      align=center />
    <Column id=opponent        title="Opponent" />
    <Column id=result_badge    title="Result"   contentType=html align=center />
    <Column id=minutes_played  title="Mins"     align=center />
    <Column id=goals           title="Goals"    align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists         title="Assists"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shots           title="Shots"    align=center />
    <Column id=shots_on_target title="SoT"      align=center />
    <Column id=key_passes      title="KP"       align=center />
    <Column id=tackles         title="Tackles"  align=center />
    <Column id=yellow_cards    title="YC"       align=center />
    <Column id=rating          title="Rating"   contentType=colorscale colorPalette={['white','#8b5cf6']} />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={player_match_log} rows=20>
    <Column id=match_date   title="Date"     />
    <Column id=opponent     title="Opponent" />
    <Column id=result_badge title=""         contentType=html align=center />
    <Column id=goals        title="G"        align=center />
    <Column id=assists      title="A"        align=center />
    <Column id=rating       title="Rating"   />
</DataTable>
</div>
