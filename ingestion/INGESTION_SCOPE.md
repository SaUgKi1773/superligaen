# Ingestion Scope — Superligaen Analytics

**Data source:** Sportmonks Football API v3  
**Subscription:** Free plan  
**Scope:** Danish Superligaen (league_id = 271), seasons 2010/2011 onwards

---

## Free Plan Constraints

- Endpoints blocked (403): `trends`, `xGFixture`, `pressure`, `expectedLineups`,
  `premiumOdds`, `inplayOdds`, `highlights`, `predictions`, `ballCoordinates`,
  `prematchNews`, `postmatchNews`
- Pagination: `per_page` max 100; returns HTTP 400 on page past last — treat as stop signal
- Date-range fixture queries: max ~100 days per window → use 90-day chunks
- League filter: API ignores `leagueIds` query param on date-range fixture endpoints;
  filter client-side on `league_id == 271`

---

## Endpoints

### 1. Types (Core API)
**URL:** `https://api.sportmonks.com/v3/core/types`  
**Frequency:** Once per full load (lookup table — rarely changes)  
**Includes:** none (flat entity)  
**Filters:** none  
**Bronze table:** `sportmonks__types`  
**Notes:** Decodes all `type_id` values used across every other endpoint (events, statistics, lineup details, standings details, etc.)

---

### 2. League
**URL:** `/v3/football/leagues/{league_id}`  
**Frequency:** Once per full load  
**Includes:** none (we only need the league record itself)  
**Filters:** `league_id = 271`  
**Bronze table:** `sportmonks__league`  
**Available but skipped includes:** `sport`, `country`, `stages`, `currentSeason`, `seasons`, `latest`, `upcoming`, `inplay`, `today`  
**Notes:** Season and stage data fetched via dedicated endpoints below

---

### 3. Seasons
**URL:** `/v3/football/leagues/{league_id}?include=seasons`  
**Frequency:** Once per full load  
**Includes:** `seasons` (embedded in league response)  
**Filters:** `league_id = 271`; client-side filter `season.name >= "2010"`  
**Bronze table:** `sportmonks__seasons`  
**Notes:** Drives the season_id list used by fixtures, squads, standings, topscorers, and stage/round endpoints

---

### 4. Stages
**URL:** `/v3/football/stages/seasons/{season_id}`  
**Frequency:** Once per season on full load  
**Includes:** none  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__stages`  
**Notes:** Stage names identify Regular Season vs Championship/Relegation rounds

---

### 5. Rounds
**URL:** `/v3/football/rounds/seasons/{season_id}`  
**Frequency:** Once per season on full load  
**Includes:** none  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__rounds`

---

### 6. Fixtures
**URL:** `/v3/football/fixtures/between/{from_date}/{to_date}`  
**Frequency:** Full load = all seasons in 90-day windows; incremental = last 30 days  
**Includes (all confirmed available on free plan via API probe + official docs):**
```
scores            — full-time, half-time scores per team
participants      — home/away teams with meta (winner flag, position)
venue             — stadium embedded in fixture
round             — round embedded (name, is_current, finished)
state             — match state (FT, NS, etc.)
events            — goals (14), own goals (15), penalties (16), subs (18),
                    yellow (19), red (20), yellow-red (21) cards
timeline          — shots on target (569), shots off target (570),
                    corners (126), offsides (1514) by minute
statistics        — team-level: corners (34), possession (45),
                    red cards (83), yellow cards (84), yellow-red (85)
referees.referee  — referee entity embedded
periods           — period start/end timestamps
lineups           — starting XI (type_id=11) and bench (type_id=12) per team
lineups.details   — per-player match stats: goals (52), assists (79),
                    shots total (42), shots on target (86), passes (80),
                    accurate passes (116), key passes (117), rating (118),
                    minutes played (119), touches (120), tackles (78),
                    interceptions (100), duels (105/106), dribbles (108/109),
                    clearances (101), long balls (122), fouls (56),
                    fouls drawn (96), saves (57), big chances (580/581) + more
coaches           — match-day manager per team
formations        — formation string per team (e.g. 4-4-2)
sidelined         — absent players (injured/suspended) per team
weatherreport     — temperature, wind, humidity, description at kick-off
```
**Filters:**
- Date-window chunks: 90 days each, from 2010-07-01 to today
- Client-side filter: `league_id == 271`

**Bronze table:** `sportmonks__fixtures` (raw JSON, one row per fixture, upsert on id)  
**Notes:**
- `events` — goals (14), own goals (15), penalties (16), substitutions (18), yellow cards (19), red cards (20), yellow-red cards (21)
- `timeline` — shots on target (569), shots off target (570), corners (126), offsides (1514) by minute — distinct from events
- `statistics` — team-level: corners (34), possession (45), red cards (83), yellow cards (84), yellow-red cards (85)
- `lineups` — starting XI (type_id=11) and bench (type_id=12) per team; `formation_field` and `formation_position` for starters
- `lineups.details` — per-player match stats: goals (52), assists (79), shots total (42), shots on target (86), shots off target (41), passes (80), accurate passes (116), key passes (117), rating (118), minutes played (119), touches (120), tackles (78), interceptions (100), duels total (105), duels won (106), dribbles attempted (108), dribbles succeeded (109), clearances (101), long balls (122), fouls (56), fouls drawn (96), offsides (51), saves (57), big chances created (580), big chances missed (581), and more
- `coaches` — match-day manager per team
- `formations` — formation string per team (e.g. 4-4-2)
- `sidelined` — player_id + type_id of absent players per fixture
- `weatherreport` — temperature, wind speed, humidity, description at kick-off

**Skipped includes (free plan 403):** `odds`, `trends`, `xGFixture`, `pressure`, `expectedLineups`, `inplayOdds`, `highlights`, `predictions`, `ballCoordinates`  
**Skipped includes (not analytical):** `tvStations`, `comments`, `metadata`, `league`, `season`, `stage`, `group`, `aggregate`

---

### 7. Standings
**URL:** `/v3/football/standings/seasons/{season_id}`  
**Frequency:** Once per season on full load; current season on incremental  
**Includes:** `details`  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__standings`  
**Available includes:** `participant`, `season`, `league`, `stage`, `group`, `round`, `rule`, `details`, `form`, `sport`  
**Notes:**
- `details` contains the full breakdown of stats by type_id (overall/home/away W/D/L, goals, goal diff, points, streak)
- `form` — last 5 match results per team (available if needed later)

---

### 8. Teams
**URL:** `/v3/football/teams/seasons/{season_id}`  
**Frequency:** Once per season on full load  
**Includes:** `coaches;venue`  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__teams`  
**Available includes:** `sport`, `country`, `venue`, `coaches`, `rivals`, `players`, `latest`, `upcoming`, `seasons`, `activeSeasons`, `sidelined`, `sidelinedHistory`, `statistics`, `trophies`, `socials`  
**Notes:** `statistics` and `trophies` are interesting but bulky — can be added later; `rivals` already fetched as a separate endpoint

---

### 9. Squads (Players per Team per Season)
**URL:** `/v3/football/squads/seasons/{season_id}/teams/{team_id}`  
**Frequency:** Once per season on full load  
**Includes:** `player;position`  
**Filters:** one request per (season_id, team_id) pair  
**Bronze table:** `sportmonks__squads`  
**Notes:** Provides player metadata (name, DOB, height, weight, image) and position per season

---

### 10. Coaches
**URL:** `/v3/football/coaches/teams/{team_id}`  
**Frequency:** Full load only — global truncate + reload  
**Includes:** none  
**Filters:** one request per team_id collected across all seasons  
**Bronze table:** `sportmonks__coaches`  
**Available includes:** `sport`, `country`, `teams`, `statistics`, `nationality`, `trophies`, `player`, `fixtures`  
**Notes:** Full coaching history per team. Match-day coach is also embedded per fixture via the `coaches` fixture include. No `coaches/seasons/{id}` endpoint exists.

---

### 11. Referees
**URL:** `/v3/football/referees/seasons/{season_id}`  
**Frequency:** Once per season on full load  
**Includes:** none  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__referees`  
**Available includes:** `sport`, `country`, `statistics`, `nationality`, `city`

---

### 12. Venues
**URL:** `/v3/football/venues/seasons/{season_id}`  
**Frequency:** Once per season on full load  
**Includes:** none  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__venues`  
**Available includes:** `country`, `city`, `fixtures`

---

### 13. Topscorers
**URL:** `/v3/football/topscorers/seasons/{season_id}`  
**Frequency:** Once per season on full load; current season on incremental  
**Includes:** `player;team;type`  
**Filters:** one request per season_id  
**Bronze table:** `sportmonks__topscorers`  
**Notes:** Returns top 25 per type (goals, assists, cards); includes player and team metadata embedded

---

### 14. Transfers
**URL:** `/v3/football/transfers/teams/{team_id}`  
**Frequency:** Once per team on full load  
**Includes:** `player;fromTeam;toTeam;type`  
**Filters:** one request per team_id  
**Bronze table:** `sportmonks__transfers`  
**Available includes:** `sport`, `player`, `type`, `fromTeam`, `toTeam`, `position`, `detailedPosition`

---

### 15. Rivals
**URL:** `/v3/football/rivals/teams/{team_id}`  
**Frequency:** Once per team on full load  
**Includes:** none  
**Filters:** one request per team_id  
**Bronze table:** `sportmonks__rivals`

---

### 16. H2H (Head-to-Head)
**URL:** `/v3/football/fixtures/headtohead/{team1_id}/{team2_id}`  
**Frequency:** Once per rival pair on full load  
**Includes:** none (raw fixture records)  
**Filters:** one request per rivals pair  
**Bronze table:** `sportmonks__h2h`  
**Notes:** Rivals pairs sourced from `sportmonks__rivals`

---

### 17. Stage Topscorers
**URL:** `/v3/football/topscorers/stages/{stage_id}`  
**Frequency:** Once per stage on full load  
**Includes:** `player;team;type`  
**Filters:** one request per stage_id  
**Bronze table:** `sportmonks__stage_topscorers`

---

### 18. Stage Statistics
**URL:** `/v3/football/statistics/stages/{stage_id}`  
**Frequency:** Once per stage on full load  
**Includes:** none  
**Filters:** one request per stage_id  
**Bronze table:** `sportmonks__stage_statistics`

---

### 19. Round Statistics
**URL:** `/v3/football/statistics/rounds/{round_id}`  
**Frequency:** Once per round on full load  
**Includes:** none  
**Filters:** one request per round_id  
**Bronze table:** `sportmonks__round_statistics`

---

## Endpoints Available but Out of Scope

| Endpoint | Reason excluded |
|---|---|
| Players (all / by country) | Too broad; player data covered via squads per season |
| TV Stations | Not analytical |
| News (pre/post match) | Requires paid plan |
| Odds / Premium Odds | Out of scope for analytics; 3,250+ rows per fixture |
| Expected Goals (xG) | Requires paid plan |
| Predictions | Requires paid plan |
| Schedules | Redundant with fixtures |
| Live scores | Not needed for historical analytics |

---

## Incremental Load Strategy

| Endpoint | Full load | Incremental |
|---|---|---|
| Types | ✅ | ❌ (static) |
| League | ✅ | ❌ (static) |
| Seasons | ✅ | ✅ (new seasons may start) |
| Stages / Rounds | ✅ | ✅ (per new season) |
| Fixtures | ✅ (all windows) | ✅ (last 30 days) |
| Standings | ✅ | ✅ (current season only) |
| Teams | ✅ | ✅ (current season only) |
| Squads | ✅ | ✅ (current season only) |
| Coaches | ✅ | ❌ (rarely changes) |
| Referees | ✅ | ✅ (current season only) |
| Venues | ✅ | ❌ (rarely changes) |
| Topscorers | ✅ | ✅ (current season + stages) |
| Transfers | ✅ | ✅ (last 90 days window) |
| Rivals / H2H | ✅ | ❌ (static) |
| Stage / Round Statistics | ✅ | ✅ (current season only) |

---

## Bronze Table Summary

| Bronze table | Source endpoint | Row grain |
|---|---|---|
| `sportmonks__types` | Core types | One row per type |
| `sportmonks__league` | League by ID | One row |
| `sportmonks__seasons` | League seasons | One row per season |
| `sportmonks__stages` | Stages by season | One row per stage |
| `sportmonks__rounds` | Rounds by season | One row per round |
| `sportmonks__fixtures` | Fixtures by date range | One row per fixture (raw JSON with all includes) |
| `sportmonks__standings` | Standings by season | One row per team-season standing |
| `sportmonks__teams` | Teams by season | One row per team |
| `sportmonks__squads` | Squads by season+team | One row per player-season-team |
| `sportmonks__coaches` | Coaches by team | One row per coach |
| `sportmonks__referees` | Referees by season | One row per referee |
| `sportmonks__venues` | Venues by season | One row per venue |
| `sportmonks__topscorers` | Topscorers by season | One row per player-stat-season |
| `sportmonks__stage_topscorers` | Topscorers by stage | One row per player-stat-stage |
| `sportmonks__stage_statistics` | Statistics by stage | One row per stat-stage |
| `sportmonks__round_statistics` | Statistics by round | One row per stat-round |
| `sportmonks__transfers` | Transfers by team | One row per transfer |
| `sportmonks__rivals` | Rivals by team | One row per rivalry |
| `sportmonks__h2h` | H2H by team pair | One row per historical fixture |
