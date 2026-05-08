---
sidebar: never
hide_toc: true
title: Standings
---

```sql seasons
select distinct season from superligaen.mart_match_facts
order by season desc
```

<details class="mb-6 rounded-xl border border-blue-100 bg-blue-50">
  <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-blue-700 flex items-center gap-2">
    ℹ️ How does the Danish Superliga work?
  </summary>
  <div class="px-4 pb-4 pt-2 text-sm text-gray-700 space-y-3">
    <p><strong>Two phases, one season.</strong> All 12 teams play each other home and away in the Regular Season (22 games). After that, the league splits based on the table:</p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li><strong>Top 6</strong> → <strong>Championship Group</strong> — compete for the title and European spots</li>
      <li><strong>Bottom 6</strong> → <strong>Relegation Group</strong> — fight to stay in the division</li>
    </ul>
    <p><strong>Points carry over in full.</strong> There is no reset — every point earned in the Regular Season follows you into the playoff phase. Each group then plays 10 more games (home and away against the other 5 teams). With a maximum of 30 points still available, a large Regular Season lead is almost impossible to overturn. This means the Regular Season table is the single biggest factor in deciding the title and who goes down.</p>
    <p><strong>What's at stake in the Championship Group:</strong></p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>🏆 <strong>1st (Champion)</strong> — Champions League qualifying (2nd qualifying round)</li>
      <li>🔵 <strong>2nd</strong> — Europa League qualifying</li>
      <li>🟠 <strong>3rd</strong> — European play-off (single match vs. Relegation Group winner). Shifts to <strong>4th</strong> if the cup winner already finished in the top 3</li>
    </ul>
    <p><strong>What's at stake in the Relegation Group:</strong></p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>⚽ <strong>1st (7th overall)</strong> — European play-off (single match vs. Championship Group 3rd or 4th) for a Europa League qualifying spot</li>
      <li>⬆️ <strong>2nd–4th</strong> — Safe, remain in the Superliga</li>
      <li>⬇️ <strong>5th–6th</strong> — Directly relegated to the Danish 1st Division, no play-off</li>
    </ul>
  </div>
</details>

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql standings
select
    row_number() over (
        partition by standings_type
        order by pts desc, gd desc, gf desc
    )              as rank,
    team_name      as team,
    gp, w, d, l, gf, ga, gd, pts,
    standings_type as round_group
from (
    select
        team_name,
        standings_type,
        count(distinct match_id)                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name, standings_type
)
where standings_type != 'Regular Season'
order by standings_type, pts desc, gd desc, gf desc
```

```sql championship
select rank, team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Championship Group'
```

```sql relegation
select rank, team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Relegation Group'
```

```sql regular
select
    row_number() over (order by pts desc, gd desc, gf desc) as rank,
    team_name as team, gp, w, d, l, gf, ga, gd, pts
from (
    select
        team_name,
        count(distinct match_id)                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
      and match_round_type = 'Regular Season'
    group by team_name
)
```

```sql all_teams
select
    team_name      as team,
    sum(points_earned)                      as pts,
    sum(goals_scored)                       as gf,
    sum(goals_conceded)                     as ga,
    standings_type                          as round_group
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name, standings_type
order by
    case standings_type
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        else                           3
    end,
    pts desc
```

## {inputs.season.label} Season Standings

{#if championship.length > 0}

### 🏆 Championship Group

<DataTable data={championship} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

{/if}

{#if relegation.length > 0}

### ⬇️ Relegation Group

<DataTable data={relegation} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

{/if}

{#if regular.length > 0}

### 📋 Regular Season

<DataTable data={regular} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

{/if}

---

<BarChart
    data={all_teams}
    x=team
    y=pts
    series=round_group
    title="Points by Team — {inputs.season.label}"
    yAxisTitle="Points"
    xAxisTitle="Team"
    sort=false
    swapXY=true
/>

<BarChart
    data={all_teams}
    x=team
    y={['gf','ga']}
    title="Goals For vs Goals Against — {inputs.season.label}"
    yAxisTitle="Goals"
    xAxisTitle="Team"
    sort=false
    swapXY=true
    colorPalette={['#22c55e','#ef4444']}
/>
