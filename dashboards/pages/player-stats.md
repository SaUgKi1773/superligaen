---
sidebar: never
hide_toc: true
title: Player Statistics
---

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_player_stats
  group by season
) order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as sort_order
  union all
  select distinct team_name, 1
  from superligaen.mart_player_stats
  where season = '${inputs.season.value}'
) order by sort_order, team_name
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key `${inputs.season.value}`}
<Dropdown data={teams} name=team value=team_name label=team_name defaultValue="All Teams" />
{/key}

```sql scorers
select
    player_name,
    team_name,
    player_photo,
    player_position,
    count(distinct match_id)                                                   as appearances,
    sum(minutes_played)                                                        as minutes_played,
    sum(goals_scored)                                                          as goals,
    sum(assists)                                                               as assists,
    sum(goals_scored) + sum(assists)                                           as goal_contributions,
    sum(penalty_scored)                                                        as penalties,
    sum(shots_total)                                                           as shots,
    sum(shots_on_target)                                                       as shots_on_target,
    round(100.0 * sum(goals_scored) / nullif(sum(shots_on_target), 0), 1)     as conversion_pct,
    round(sum(goals_scored)::double / nullif(count(distinct match_id), 0), 2) as goals_per_match,
    sum(yellow_cards)                                                          as yellow_cards,
    sum(red_cards)                                                             as red_cards
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (team_name = '${inputs.team.value}' or '${inputs.team.value}' = 'All Teams')
group by player_name, team_name, player_photo, player_position
having sum(goals_scored) > 0
order by goals desc, assists desc
```

```sql assisters
select
    player_name,
    team_name,
    player_position,
    count(distinct match_id)                                                     as appearances,
    sum(assists)                                                                 as assists,
    sum(goals_scored)                                                            as goals,
    sum(goals_scored) + sum(assists)                                             as goal_contributions,
    sum(key_passes)                                                              as key_passes,
    sum(chances_created)                                                         as chances_created,
    round(sum(assists)::double / nullif(count(distinct match_id), 0), 2)         as assists_per_match
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (team_name = '${inputs.team.value}' or '${inputs.team.value}' = 'All Teams')
group by player_name, team_name, player_position
having sum(assists) > 0
order by assists desc, goals desc
```

```sql season_kpis
select
    count(distinct player_name)                                               as total_players,
    sum(goals_scored)                                                         as total_goals,
    sum(assists)                                                              as total_assists,
    round(avg(nullif(rating, 0)), 2)                                         as avg_rating
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (team_name = '${inputs.team.value}' or '${inputs.team.value}' = 'All Teams')
```

## Player Statistics — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_players  title="Players"         /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_goals    title="Goals Scored"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_assists   title="Assists"         /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=avg_rating      title="Avg Rating"      /></div>
</div>

---

## Top Scorers

<DataTable data={scorers} rows=20>
    <Column id=player_name         title="Player"         wrap=true />
    <Column id=team_name           title="Team"           wrap=true />
    <Column id=player_position     title="Position"       />
    <Column id=appearances         title="Apps"           align=center />
    <Column id=goals               title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=assists             title="Assists"        contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=goal_contributions  title="G+A"            contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=penalties           title="Pen"            align=center />
    <Column id=shots_on_target     title="SoT"            align=center />
    <Column id=conversion_pct      title="Conv %"         fmt='0.0"%"' />
    <Column id=goals_per_match     title="Goals/Match"    />
    <Column id=yellow_cards        title="YC"             align=center />
    <Column id=red_cards           title="RC"             align=center />
</DataTable>

---

## Top Assisters

<DataTable data={assisters} rows=20>
    <Column id=player_name         title="Player"         wrap=true />
    <Column id=team_name           title="Team"           wrap=true />
    <Column id=player_position     title="Position"       />
    <Column id=appearances         title="Apps"           align=center />
    <Column id=assists             title="Assists"        contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=goals               title="Goals"          align=center />
    <Column id=goal_contributions  title="G+A"            contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=key_passes          title="Key Passes"     contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=chances_created     title="Chances"        align=center />
    <Column id=assists_per_match   title="Assists/Match"  />
</DataTable>

---

## Player Deep Dive

```sql all_players
select distinct player_name
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and (team_name = '${inputs.team.value}' or '${inputs.team.value}' = 'All Teams')
order by player_name
```

<Dropdown data={all_players} name=player value=player_name label=player_name defaultValue={all_players[0]?.player_name} />

```sql player_season_kpis
select
    player_name,
    team_name,
    player_position,
    player_nationality,
    count(distinct match_id)                                                   as appearances,
    count(distinct match_id) filter (where appearance_type = 'Starter')       as starts,
    sum(minutes_played)                                                        as minutes_played,
    sum(goals_scored)                                                          as goals,
    sum(assists)                                                               as assists,
    sum(goals_scored) + sum(assists)                                           as goal_contributions,
    sum(shots_total)                                                           as shots,
    sum(shots_on_target)                                                       as shots_on_target,
    round(100.0 * sum(goals_scored) / nullif(sum(shots_on_target), 0), 1)     as conversion_pct,
    sum(passes_total)                                                          as passes,
    sum(passes_accurate)                                                       as passes_accurate,
    round(100.0 * sum(passes_accurate) / nullif(sum(passes_total), 0), 1)     as pass_accuracy,
    sum(key_passes)                                                            as key_passes,
    sum(tackles)                                                               as tackles,
    sum(tackles_won)                                                           as tackles_won,
    sum(interceptions)                                                         as interceptions,
    sum(clearances)                                                            as clearances,
    sum(duels_total)                                                           as duels,
    sum(duels_won)                                                             as duels_won,
    round(100.0 * sum(duels_won) / nullif(sum(duels_total), 0), 1)            as duel_win_pct,
    sum(dribbles_attempts)                                                     as dribbles_attempted,
    sum(dribbles_completed)                                                    as dribbles_completed,
    sum(fouls_committed)                                                       as fouls,
    sum(yellow_cards)                                                          as yellow_cards,
    sum(red_cards)                                                             as red_cards,
    sum(offsides)                                                              as offsides,
    round(avg(nullif(rating, 0)), 2)                                           as avg_rating
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, team_name, player_position, player_nationality
```

```sql player_match_log
select
    match_date,
    match_round_name                                                           as round,
    opponent_team_name                                                         as opponent,
    team_side,
    result,
    appearance_type,
    minutes_played,
    goals_scored                                                               as goals,
    assists,
    shots_on_target                                                            as sot,
    key_passes,
    tackles,
    fouls_committed                                                            as fouls,
    yellow_cards                                                               as yc,
    red_cards                                                                  as rc,
    rating
from superligaen.mart_player_stats
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date asc
```

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4 mt-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=appearances       title="Appearances"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=goals             title="Goals"           /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=assists           title="Assists"         /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=avg_rating        title="Avg Rating"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=minutes_played    title="Minutes Played"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=shots_on_target   title="Shots on Target" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=key_passes        title="Key Passes"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=conversion_pct    title="Shot Conv %"     fmt='0.0"%"' /></div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=pass_accuracy     title="Pass Accuracy %"  fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=duel_win_pct      title="Duel Win %"       fmt='0.0"%"' /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=tackles           title="Tackles"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=interceptions     title="Interceptions"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=yellow_cards      title="Yellow Cards"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=red_cards         title="Red Cards"        /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=fouls             title="Fouls Committed"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={player_season_kpis} value=offsides          title="Offsides"         /></div>
</div>

### Match Log

<DataTable data={player_match_log} rows=40>
    <Column id=match_date       title="Date"        />
    <Column id=round            title="Round"       />
    <Column id=opponent         title="Opponent"    wrap=true />
    <Column id=team_side        title="Side"        />
    <Column id=result           title="Result"      />
    <Column id=appearance_type  title="Type"        />
    <Column id=minutes_played   title="Mins"        align=center />
    <Column id=goals            title="G"           contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=assists          title="A"           contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=sot              title="SoT"         align=center />
    <Column id=key_passes       title="KP"          align=center />
    <Column id=tackles          title="Tkl"         align=center />
    <Column id=fouls            title="FC"          align=center />
    <Column id=yc               title="YC"          contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=rc               title="RC"          contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=rating           title="Rating"      contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>
