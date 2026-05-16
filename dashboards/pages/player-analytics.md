---
sidebar: never
hide_toc: true
title: Player Intelligence
---

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_player_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

```sql position_options
select * from (values
  ('All Positions'),
  ('Attacker'),
  ('Midfielder'),
  ('Defender'),
  ('Goalkeeper')
) as t(player_position)
```

<Dropdown data={position_options} name=position value=player_position label=player_position defaultValue="All Positions" />

```sql scoring_podium
select
    player_name,
    player_photo,
    team_name,
    team_logo,
    sum(goals_scored)::int                                                         as goals,
    sum(assists)::int                                                              as assists,
    count(distinct match_id)::int                                                  as matches,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)           as goals_per90,
    row_number() over (order by sum(goals_scored) desc, sum(assists) desc)::int   as podium_rank
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, player_photo, team_name, team_logo
having sum(goals_scored) >= 1
order by goals desc
limit 3
```

```sql per90_leaderboard
select
    row_number() over (order by sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0) desc)::int as rank,
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    sum(goals_scored)::int                                                                 as goals,
    sum(assists)::int                                                                      as assists,
    count(distinct match_id)::int                                                          as matches,
    sum(minutes_played)::int                                                               as minutes,
    round(sum(goals_scored) * 90.0      / nullif(sum(minutes_played), 0), 2)              as goals_per90,
    round(sum(assists) * 90.0           / nullif(sum(minutes_played), 0), 2)              as assists_per90,
    round((sum(goals_scored)+sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2)    as contributions_per90,
    round(sum(shots_total) * 90.0       / nullif(sum(minutes_played), 0), 2)              as shots_per90,
    round(avg(rating), 2)                                                                  as avg_rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, player_photo, team_name, team_logo, player_position
having sum(minutes_played) >= 450
order by goals_per90 desc
limit 30
```

```sql rating_leaders
select
    row_number() over (order by avg(rating) desc)::int   as rank,
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    round(avg(rating), 2)                                as avg_rating,
    count(distinct match_id)::int                        as matches,
    sum(goals_scored)::int                               as goals,
    sum(assists)::int                                    as assists,
    sum(minutes_played)::int                             as minutes
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and rating is not null
  and rating > 0
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, player_photo, team_name, team_logo, player_position
having count(distinct match_id) >= 5
order by avg_rating desc
limit 20
```

```sql defensive_leaderboard
select
    row_number() over (order by sum(tackles) * 90.0 / nullif(sum(minutes_played), 0) desc)::int as rank,
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    sum(tackles)::int                                                              as tackles,
    sum(interceptions)::int                                                        as interceptions,
    sum(clearances)::int                                                           as clearances,
    sum(aerials_won)::int                                                          as aerials_won,
    round(sum(tackles) * 90.0       / nullif(sum(minutes_played), 0), 2)          as tackles_per90,
    round(sum(interceptions) * 90.0 / nullif(sum(minutes_played), 0), 2)          as interceptions_per90,
    count(distinct match_id)::int                                                  as matches,
    sum(minutes_played)::int                                                       as minutes
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, player_photo, team_name, team_logo, player_position
having sum(minutes_played) >= 450
order by tackles_per90 desc
limit 20
```

```sql creators_leaderboard
select
    row_number() over (order by sum(key_passes) * 90.0 / nullif(sum(minutes_played), 0) desc)::int as rank,
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    sum(assists)::int                                                                  as assists,
    sum(key_passes)::int                                                               as key_passes,
    sum(big_chances_created)::int                                                      as big_chances,
    sum(passes_accurate)::int                                                          as accurate_passes,
    round(sum(key_passes) * 90.0         / nullif(sum(minutes_played), 0), 2)         as key_passes_per90,
    round(sum(big_chances_created) * 90.0/ nullif(sum(minutes_played), 0), 2)         as big_chances_per90,
    round(100.0 * sum(passes_accurate)   / nullif(sum(passes_total), 0), 1)           as pass_accuracy,
    count(distinct match_id)::int                                                      as matches,
    sum(minutes_played)::int                                                           as minutes
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, player_photo, team_name, team_logo, player_position
having sum(minutes_played) >= 450
order by key_passes_per90 desc
limit 20
```

```sql efficiency_scatter
select
    player_name,
    team_name,
    player_position,
    sum(minutes_played)::int                                                          as minutes,
    sum(goals_scored)::int                                                            as goals,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)              as goals_per90,
    round(avg(rating), 2)                                                             as avg_rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
group by player_name, team_name, player_position
having sum(minutes_played) >= 450
  and sum(goals_scored) > 0
order by goals_per90 desc
```

```sql players_for_dropdown
select distinct player_name
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (
    '${inputs.position.value}' = 'All Positions'
    or player_position = '${inputs.position.value}'
  )
order by player_name
```

<Dropdown data={players_for_dropdown} name=player value=player_name label=player_name />

```sql player_kpis
select
    player_name,
    player_photo,
    team_name,
    team_logo,
    player_position,
    count(distinct match_id)::int                                                     as matches,
    sum(minutes_played)::int                                                          as minutes,
    sum(goals_scored)::int                                                            as goals,
    sum(assists)::int                                                                 as assists,
    sum(shots_total)::int                                                             as shots,
    sum(shots_on_target)::int                                                         as shots_on_target,
    sum(key_passes)::int                                                              as key_passes,
    sum(tackles)::int                                                                 as tackles,
    round(avg(rating), 2)                                                             as avg_rating,
    round(sum(goals_scored) * 90.0 / nullif(sum(minutes_played), 0), 2)              as goals_per90,
    round(sum(assists) * 90.0 / nullif(sum(minutes_played), 0), 2)                   as assists_per90,
    round(100.0 * sum(passes_accurate) / nullif(sum(passes_total), 0), 1)            as pass_accuracy,
    round(100.0 * sum(goals_scored) / nullif(sum(shots_total), 0), 1)                as shot_accuracy
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, team_name, team_logo, player_position
```

```sql player_match_log
select
    match_date,
    match_round_name                    as round,
    opponent_team_name                  as opponent,
    team_side                           as home_away,
    result,
    minutes_played,
    goals_scored                        as goals,
    assists,
    shots_total                         as shots,
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

---

## Player Intelligence — {inputs.season.value}

---

## Scoring Podium

<div class="grid grid-cols-3 gap-4 md:gap-6 mb-8">
  {#each scoring_podium as p}
    <div class="relative rounded-2xl border p-4 md:p-6 text-center shadow-md flex flex-col items-center
      {p.podium_rank === 1 ? 'border-amber-300 bg-gradient-to-b from-amber-50 to-yellow-100 order-first md:scale-105' :
       p.podium_rank === 2 ? 'border-gray-300 bg-gradient-to-b from-gray-50 to-gray-100' :
       'border-orange-200 bg-gradient-to-b from-orange-50 to-amber-50'}">
      <div class="text-2xl md:text-3xl font-black mb-2
        {p.podium_rank === 1 ? 'text-amber-500' : p.podium_rank === 2 ? 'text-gray-400' : 'text-orange-400'}">
        {p.podium_rank === 1 ? '🥇' : p.podium_rank === 2 ? '🥈' : '🥉'}
      </div>
      <img src="{p.player_photo}" alt="{p.player_name}"
        class="w-16 h-16 md:w-20 md:h-20 rounded-full object-cover border-4 shadow-lg mb-3
          {p.podium_rank === 1 ? 'border-amber-400' : p.podium_rank === 2 ? 'border-gray-300' : 'border-orange-300'}"
        onerror="this.style.display='none'" />
      <div class="font-extrabold text-gray-800 text-sm md:text-base leading-tight">{p.player_name}</div>
      <div class="flex items-center justify-center gap-1 mt-1 mb-3">
        <img src="{p.team_logo}" alt="{p.team_name}" class="h-4 w-4 object-contain" onerror="this.style.display='none'" />
        <span class="text-xs text-gray-400">{p.team_name}</span>
      </div>
      <div class="text-3xl md:text-4xl font-black
        {p.podium_rank === 1 ? 'text-amber-500' : p.podium_rank === 2 ? 'text-gray-500' : 'text-orange-400'}">
        {p.goals}
      </div>
      <div class="text-xs text-gray-400 mt-1">goals · {p.matches} apps</div>
    </div>
  {/each}
</div>

---

## Attacking Efficiency — Goals per 90

*Min. 450 minutes played. Bubble = total goals.*

<ScatterPlot
    data={efficiency_scatter}
    x=minutes
    y=goals_per90
    series=player_position
    xAxisTitle="Minutes Played"
    yAxisTitle="Goals per 90"
    title="Goal Efficiency — {inputs.season.value}"
    tooltipColumns={[{id: 'player_name', title: 'Player'}, {id: 'team_name', title: 'Team'}, {id: 'goals', title: 'Goals'}, {id: 'goals_per90', title: 'G/90'}, {id: 'avg_rating', title: 'Rating'}]}
/>

---

## Goals per 90 Leaderboard

<div class="hidden md:block">
<DataTable data={per90_leaderboard} rows=20>
    <Column id=rank              title="#"            align=center />
    <Column id=player_photo      title=""             contentType=image height=32 />
    <Column id=player_name       title="Player"       />
    <Column id=team_logo         title=""             contentType=image height=24 />
    <Column id=team_name         title="Team"         />
    <Column id=player_position   title="Position"     />
    <Column id=goals             title="Goals"        align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists           title="Assists"      align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=goals_per90       title="G/90"         contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=assists_per90     title="A/90"         contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shots_per90       title="Shots/90"     />
    <Column id=avg_rating        title="Rating"       contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=matches           title="MP"           align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={per90_leaderboard} rows=20>
    <Column id=rank         title="#"        align=center />
    <Column id=player_name  title="Player"   />
    <Column id=goals        title="G"        align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=goals_per90  title="G/90"     contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=avg_rating   title="Rating"   />
</DataTable>
</div>

---

## Highest Rated Players

<div class="hidden md:block">
<DataTable data={rating_leaders} rows=20>
    <Column id=rank            title="#"         align=center />
    <Column id=player_photo    title=""          contentType=image height=32 />
    <Column id=player_name     title="Player"    />
    <Column id=team_logo       title=""          contentType=image height=24 />
    <Column id=team_name       title="Team"      />
    <Column id=player_position title="Position"  />
    <Column id=avg_rating      title="Avg Rating" contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=matches         title="MP"        align=center />
    <Column id=goals           title="Goals"     align=center />
    <Column id=assists         title="Assists"   align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={rating_leaders} rows=20>
    <Column id=rank        title="#"       align=center />
    <Column id=player_name title="Player"  />
    <Column id=avg_rating  title="Rating"  contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=goals       title="G"       align=center />
    <Column id=assists     title="A"       align=center />
</DataTable>
</div>

---

## Creative Midfielders — Key Passes per 90

<div class="hidden md:block">
<DataTable data={creators_leaderboard} rows=20>
    <Column id=rank               title="#"             align=center />
    <Column id=player_photo       title=""              contentType=image height=32 />
    <Column id=player_name        title="Player"        />
    <Column id=team_logo          title=""              contentType=image height=24 />
    <Column id=team_name          title="Team"          />
    <Column id=player_position    title="Position"      />
    <Column id=key_passes_per90   title="Key Pass/90"   contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=big_chances_per90  title="Big Chance/90" contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=assists            title="Assists"       align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=pass_accuracy      title="Pass Acc %"    fmt='0.0"%"' contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=matches            title="MP"            align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={creators_leaderboard} rows=20>
    <Column id=rank              title="#"       align=center />
    <Column id=player_name       title="Player"  />
    <Column id=key_passes_per90  title="KP/90"   contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists           title="A"       align=center />
    <Column id=pass_accuracy     title="Pass %"  fmt='0.0"%"' />
</DataTable>
</div>

---

## Defensive Workrate — Tackles per 90

<div class="hidden md:block">
<DataTable data={defensive_leaderboard} rows=20>
    <Column id=rank                  title="#"             align=center />
    <Column id=player_photo          title=""              contentType=image height=32 />
    <Column id=player_name           title="Player"        />
    <Column id=team_logo             title=""              contentType=image height=24 />
    <Column id=team_name             title="Team"          />
    <Column id=player_position       title="Position"      />
    <Column id=tackles_per90         title="Tackles/90"    contentType=colorscale colorPalette={['white','#14b8a6']} />
    <Column id=interceptions_per90   title="Interc/90"     contentType=colorscale colorPalette={['white','#0ea5e9']} />
    <Column id=tackles               title="Total Tackles" align=center />
    <Column id=interceptions         title="Interceptions" align=center />
    <Column id=clearances            title="Clearances"    align=center />
    <Column id=aerials_won           title="Aerials Won"   align=center />
    <Column id=matches               title="MP"            align=center />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={defensive_leaderboard} rows=20>
    <Column id=rank             title="#"       align=center />
    <Column id=player_name      title="Player"  />
    <Column id=tackles_per90    title="Tck/90"  contentType=colorscale colorPalette={['white','#14b8a6']} />
    <Column id=interceptions    title="Int"     align=center />
</DataTable>
</div>

---

## Player Deep Dive

{#each player_kpis as p}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{p.player_photo}" alt="{p.player_name}"
      class="h-24 w-24 rounded-full object-cover border-4 border-white/20 shadow-xl"
      onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl font-extrabold text-white">{p.player_name}</div>
      <div class="flex items-center justify-center md:justify-start gap-2 mt-1">
        <img src="{p.team_logo}" alt="{p.team_name}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
        <span class="text-gray-300 text-sm">{p.team_name}</span>
        <span class="text-gray-500 text-sm">· {p.player_position}</span>
      </div>
      <div class="flex flex-wrap justify-center md:justify-start gap-6 mt-5">
        <div class="text-center"><div class="text-2xl font-black text-amber-400">{p.goals}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Goals</div></div>
        <div class="text-center"><div class="text-2xl font-black text-blue-400">{p.assists}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Assists</div></div>
        <div class="text-center"><div class="text-2xl font-black text-purple-400">{p.avg_rating}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Avg Rating</div></div>
        <div class="text-center"><div class="text-2xl font-black text-white">{p.matches}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Apps</div></div>
        <div class="text-center"><div class="text-2xl font-black text-green-400">{p.goals_per90}</div><div class="text-xs text-gray-400 uppercase tracking-widest">G/90</div></div>
        <div class="text-center"><div class="text-2xl font-black text-teal-400">{p.pass_accuracy}%</div><div class="text-xs text-gray-400 uppercase tracking-widest">Pass Acc</div></div>
      </div>
    </div>
  </div>
</div>
{/each}

<div class="hidden md:block">
<DataTable data={player_match_log} rows=15>
    <Column id=match_date     title="Date"      />
    <Column id=round          title="Round"     />
    <Column id=home_away      title="H/A"       align=center />
    <Column id=opponent       title="Opponent"  />
    <Column id=result         title="Result"    />
    <Column id=minutes_played title="Mins"      align=center />
    <Column id=goals          title="Goals"     align=center contentType=colorscale colorPalette={['white','#f59e0b']} />
    <Column id=assists        title="Assists"   align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shots          title="Shots"     align=center />
    <Column id=key_passes     title="KP"        align=center />
    <Column id=tackles        title="Tackles"   align=center />
    <Column id=yellow_cards   title="YC"        align=center />
    <Column id=rating         title="Rating"    contentType=colorscale colorPalette={['white','#8b5cf6']} />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={player_match_log} rows=15>
    <Column id=match_date     title="Date"     />
    <Column id=opponent       title="Opponent" />
    <Column id=result         title="Result"   />
    <Column id=goals          title="G"        align=center />
    <Column id=assists        title="A"        align=center />
    <Column id=rating         title="Rating"   />
</DataTable>
</div>
