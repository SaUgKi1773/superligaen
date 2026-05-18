<script>
  export let lineup = [];   // starters only
  export let subs   = [];   // substitutes
  export let home_team = '';
  export let away_team = '';

  const W = 700, H = 560;
  const PX = 12, PY = 14, PW = 676, PH = 532;
  const CX = PX + PW / 2;   // 350
  const CY = PY + PH / 2;   // 280
  const R  = 20;
  const VPAD = 10;           // vertical padding for player spread

  // Fixed X column per position tier (as fraction of PW) — home stays left of 0.5, away right
  const posX = {
    home: { Goalkeeper: 0.055, Defender: 0.185, Midfielder: 0.335, Attacker: 0.455 },
    away: { Goalkeeper: 0.945, Defender: 0.815, Midfielder: 0.665, Attacker: 0.545 },
  };

  // Left = small y (top), Right = large y (bottom); away is mirrored
  function sideOrder(posName) {
    if (!posName) return 0;
    if (posName.includes('Left'))  return -1;
    if (posName.includes('Right')) return  1;
    return 0;
  }

  function computeLayout(players, side) {
    const rows = {};
    for (const p of players) {
      const pos = ['Goalkeeper','Defender','Midfielder','Attacker'].includes(p.position_group)
        ? p.position_group : 'Midfielder';
      if (!rows[pos]) rows[pos] = [];
      rows[pos].push(p);
    }
    const out = [];
    for (const [pos, group] of Object.entries(rows)) {
      const x = PX + (posX[side][pos] ?? 0.5) * PW;
      const sorted = [...group].sort((a, b) => {
        const d = sideOrder(a.position_name) - sideOrder(b.position_name);
        return side === 'away' ? -d : d;
      });
      const n = sorted.length;
      sorted.forEach((p, i) => {
        const y = PY + VPAD + ((i + 1) / (n + 1)) * (PH - 2 * VPAD);
        out.push({ ...p, cx: x, cy: y });
      });
    }
    return out;
  }

  $: homePlayers    = computeLayout(lineup.filter(p => p.team_side === 'Home'), 'home');
  $: awayPlayers    = computeLayout(lineup.filter(p => p.team_side === 'Away'), 'away');
  $: allPlayers     = [...homePlayers, ...awayPlayers];
  $: homeSubs       = subs.filter(p => p.team_side === 'Home');
  $: awaySubs       = subs.filter(p => p.team_side === 'Away');
  $: homeRow        = lineup.find(p => p.team_side === 'Home');
  $: awayRow        = lineup.find(p => p.team_side === 'Away');
  $: homeFormation  = homeRow?.formation ?? '';
  $: awayFormation  = awayRow?.formation ?? '';
  $: homeLogo       = homeRow?.team_logo ?? '';
  $: awayLogo       = awayRow?.team_logo ?? '';

  let selected = null;
  function toggle(p) {
    selected = (selected?.player_name === p.player_name && selected?.team_side === p.team_side) ? null : p;
  }

  const statDefs = [
    { key: 'goals_scored',        label: 'Goals'           },
    { key: 'assists',             label: 'Assists'         },
    { key: 'shots_total',         label: 'Shots'           },
    { key: 'shots_on_target',     label: 'Shots on Target' },
    { key: 'key_passes',          label: 'Key Passes'      },
    { key: 'big_chances_created', label: 'Big Chances'     },
    { key: 'dribbles_completed',  label: 'Dribbles'        },
    { key: 'tackles',             label: 'Tackles'         },
    { key: 'interceptions',       label: 'Interceptions'   },
    { key: 'clearances',          label: 'Clearances'      },
    { key: 'aerials_won',         label: 'Aerials Won'     },
    { key: 'blocks',              label: 'Blocks'          },
    { key: 'fouls_committed',     label: 'Fouls'           },
    { key: 'saves',               label: 'Saves'           },
    { key: 'yellow_cards',        label: 'Yellow Cards'    },
    { key: 'red_cards',           label: 'Red Cards'       },
    { key: 'minutes_played',      label: 'Minutes'         },
  ];
  function visibleStats(p) { return statDefs.filter(s => p[s.key] > 0); }

  function shortName(name) {
    if (!name || name.length <= 13) return name;
    const parts = name.trim().split(' ');
    if (parts.length < 2) return name.substring(0, 13);
    return parts[0][0] + '. ' + parts.slice(1).join(' ');
  }

  function ratingColor(r) {
    if (!r)     return '#9ca3af';
    if (r >= 7.5) return '#4ade80';
    if (r >= 6.5) return '#fde68a';
    return '#fca5a5';
  }

  function emojiRow(p) {
    const parts = [];
    if (p.goals_scored > 0)  parts.push('⚽'.repeat(Math.min(p.goals_scored, 3)) + (p.goals_scored > 3 ? p.goals_scored : ''));
    if (p.assists > 0)       parts.push('🎯'.repeat(Math.min(p.assists, 2))       + (p.assists > 2 ? p.assists : ''));
    if (p.yellow_cards > 0)  parts.push('🟨');
    if (p.red_cards > 0)     parts.push('🟥');
    return parts.join(' ');
  }

  // Pitch measurements
  const penDepth  = 104;   // penalty box depth (from goal line)
  const penHalf   = 106;   // half-height of penalty box
  const gbDepth   = 38;    // goal box depth
  const gbHalf    = 50;    // half-height of goal box
  const goalHalf  = 26;    // half-height of goal
  const goalDepth = 10;    // goal depth extension
  const penSpot   = 70;    // penalty spot distance from goal line
</script>

{#if allPlayers.length > 0}

<!-- Formation + logo header -->
<div class="lineup-wrap formation-header">
  <div style="display:flex;align-items:center;gap:8px;">
    {#if homeLogo}<img src={homeLogo} alt={home_team} style="width:28px;height:28px;object-fit:contain;" onerror="this.style.display='none'" />{/if}
    <span style="font-size:13px;font-weight:700;color:#374151;">{homeFormation}</span>
  </div>
  <div style="display:flex;align-items:center;gap:8px;">
    <span style="font-size:13px;font-weight:700;color:#374151;">{awayFormation}</span>
    {#if awayLogo}<img src={awayLogo} alt={away_team} style="width:28px;height:28px;object-fit:contain;" onerror="this.style.display='none'" />{/if}
  </div>
</div>

<div class="lineup-wrap" style="position:relative;overflow:visible;">
  <svg viewBox="0 0 {W} {H}" style="width:100%;display:block;overflow:visible;">
    <defs>
      {#each allPlayers as p, i}
        <clipPath id="lclip-{i}"><circle cx={p.cx} cy={p.cy} r={R} /></clipPath>
      {/each}
    </defs>

    <!-- Pitch background + stripes -->
    <rect x={PX} y={PY} width={PW} height={PH} fill="#2d7a3a" />
    {#each {length: 8} as _, i}
      <rect x={PX + i*(PW/8)} y={PY} width={PW/16} height={PH} fill="#2a7236" opacity="0.5" />
    {/each}

    <!-- Pitch outline -->
    <rect x={PX} y={PY} width={PW} height={PH} fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="2" />

    <!-- Center vertical line -->
    <line x1={CX} y1={PY} x2={CX} y2={PY+PH} stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />

    <!-- Center circle -->
    <circle cx={CX} cy={CY} r="52" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <circle cx={CX} cy={CY} r="3"  fill="rgba(255,255,255,0.85)" />

    <!-- Left (home) goal -->
    <rect x={PX - goalDepth} y={CY - goalHalf} width={goalDepth} height={goalHalf*2}
      fill="rgba(255,255,255,0.1)" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Left goal box -->
    <rect x={PX} y={CY - gbHalf} width={gbDepth} height={gbHalf*2}
      fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Left penalty box -->
    <rect x={PX} y={CY - penHalf} width={penDepth} height={penHalf*2}
      fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Left penalty spot -->
    <circle cx={PX + penSpot} cy={CY} r="2.5" fill="rgba(255,255,255,0.85)" />

    <!-- Right (away) goal -->
    <rect x={PX + PW} y={CY - goalHalf} width={goalDepth} height={goalHalf*2}
      fill="rgba(255,255,255,0.1)" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Right goal box -->
    <rect x={PX + PW - gbDepth} y={CY - gbHalf} width={gbDepth} height={gbHalf*2}
      fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Right penalty box -->
    <rect x={PX + PW - penDepth} y={CY - penHalf} width={penDepth} height={penHalf*2}
      fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <!-- Right penalty spot -->
    <circle cx={PX + PW - penSpot} cy={CY} r="2.5" fill="rgba(255,255,255,0.85)" />

    <!-- Corner arcs -->
    <path d="M {PX+12} {PY} A 12 12 0 0 1 {PX} {PY+12}" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <path d="M {PX+PW-12} {PY} A 12 12 0 0 0 {PX+PW} {PY+12}" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <path d="M {PX+12} {PY+PH} A 12 12 0 0 0 {PX} {PY+PH-12}" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />
    <path d="M {PX+PW-12} {PY+PH} A 12 12 0 0 1 {PX+PW} {PY+PH-12}" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" />

    <!-- Players -->
    {#each allPlayers as p, i}
      {@const isHome   = p.team_side === 'Home'}
      {@const isActive = selected?.player_name === p.player_name && selected?.team_side === p.team_side}

      <!-- Shadow -->
      <circle cx={p.cx+1} cy={p.cy+2} r={R+1} fill="rgba(0,0,0,0.3)" />

      <!-- Background -->
      <circle cx={p.cx} cy={p.cy} r={R} fill={isHome ? '#1d4ed8' : '#b91c1c'} />

      <!-- Photo -->
      {#if p.player_photo}
        <image href={p.player_photo}
          x={p.cx-R} y={p.cy-R} width={R*2} height={R*2}
          clip-path="url(#lclip-{i})"
          preserveAspectRatio="xMidYMid slice" />
      {/if}

      <!-- Ring -->
      <circle cx={p.cx} cy={p.cy} r={R} fill="none"
        stroke={isActive ? '#fbbf24' : (isHome ? '#93c5fd' : '#fca5a5')}
        stroke-width={isActive ? 3 : 1.5} />

      <!-- Name -->
      <text x={p.cx} y={p.cy + R + 13} text-anchor="middle" font-size="9" font-weight="700"
        paint-order="stroke" stroke="rgba(0,0,0,0.9)" stroke-width="3" fill="white"
        font-family="ui-sans-serif,system-ui,sans-serif"
      >{shortName(p.player_name)}</text>

      <!-- Rating -->
      {#if p.rating}
        <text x={p.cx} y={p.cy + R + 25} text-anchor="middle" font-size="9" font-weight="700"
          paint-order="stroke" stroke="rgba(0,0,0,0.9)" stroke-width="2.5" fill={ratingColor(p.rating)}
          font-family="ui-sans-serif,system-ui,sans-serif"
        >{p.rating}</text>
      {/if}

      <!-- Goal / assist / card emojis -->
      {@const emojis = emojiRow(p)}
      {#if emojis}
        <text x={p.cx} y={p.cy + R + 40} text-anchor="middle" font-size="15">{emojis}</text>
      {/if}

      <!-- Click target -->
      <circle cx={p.cx} cy={p.cy} r={R+10} fill="transparent" style="cursor:pointer;"
        on:click={() => toggle(p)}
        on:keydown={e => e.key === 'Enter' && toggle(p)}
        role="button" tabindex="0" aria-label={p.player_name}
      />
    {/each}
  </svg>

  <!-- Bottom-sheet tooltip -->
  {#if selected}
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div style="position:fixed;inset:0;z-index:100;display:flex;align-items:flex-end;justify-content:center;background:rgba(0,0,0,0.45);"
    on:click|self={() => selected = null}>
    <div style="background:white;border-radius:1rem 1rem 0 0;padding:1.25rem 1rem 2rem;width:100%;max-width:480px;max-height:65vh;overflow-y:auto;">
      <div style="width:36px;height:4px;background:#e5e7eb;border-radius:2px;margin:0 auto 1rem;"></div>
      <div style="display:flex;align-items:center;gap:12px;margin-bottom:14px;">
        <img src={selected.player_photo} alt={selected.player_name}
          style="width:52px;height:52px;border-radius:50%;object-fit:cover;border:2px solid {selected.team_side === 'Home' ? '#3b82f6' : '#ef4444'};"
          onerror="this.style.display='none'" />
        <div style="flex:1;min-width:0;">
          <div style="font-weight:800;font-size:15px;color:#111827;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{selected.player_name}</div>
          <div style="font-size:12px;color:#6b7280;margin-top:2px;">
            <span style="font-weight:700;background:{selected.team_side==='Home'?'#dbeafe':'#fee2e2'};color:{selected.team_side==='Home'?'#1d4ed8':'#b91c1c'};padding:1px 6px;border-radius:4px;margin-right:6px;">{selected.position_short_code ?? '—'}</span>
            {selected.team_name}
          </div>
        </div>
        {#if selected.rating}
          <div style="text-align:center;flex-shrink:0;">
            <div style="font-size:26px;font-weight:900;color:{selected.rating >= 7.5 ? '#16a34a' : selected.rating >= 6.5 ? '#d97706' : '#dc2626'};">{selected.rating}</div>
            <div style="font-size:10px;color:#9ca3af;">Rating</div>
          </div>
        {/if}
      </div>
      {#if visibleStats(selected).length > 0}
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:7px;">
          {#each visibleStats(selected) as s}
            <div style="background:#f9fafb;border-radius:8px;padding:8px 12px;display:flex;justify-content:space-between;align-items:center;">
              <span style="font-size:11px;color:#6b7280;">{s.label}</span>
              <span style="font-size:14px;font-weight:800;color:#111827;">{selected[s.key]}</span>
            </div>
          {/each}
        </div>
      {:else}
        <p style="text-align:center;color:#9ca3af;font-size:13px;margin:1rem 0;">No stats recorded</p>
      {/if}
    </div>
  </div>
  {/if}
</div>

<!-- Substitutes -->
{#if homeSubs.length > 0 || awaySubs.length > 0}
<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px;font-size:12px;">
  <div>
    <div style="font-weight:700;color:#374151;margin-bottom:6px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;">🔄 {home_team} Subs</div>
    {#each homeSubs as p}
      <div style="display:flex;align-items:center;gap:7px;padding:4px 0;border-bottom:1px solid #f3f4f6;">
        <img src={p.player_photo} alt={p.player_name}
          style="width:22px;height:22px;border-radius:50%;object-fit:cover;flex-shrink:0;"
          onerror="this.style.display='none'" />
        <span style="background:#dbeafe;color:#1d4ed8;font-size:10px;font-weight:700;padding:1px 5px;border-radius:3px;flex-shrink:0;">{p.position_short_code ?? '—'}</span>
        <span style="color:#374151;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{p.player_name}</span>
        {#if p.rating}<span style="font-weight:700;color:{ratingColor(p.rating)};flex-shrink:0;">{p.rating}</span>{/if}
      </div>
    {/each}
  </div>
  <div>
    <div style="font-weight:700;color:#374151;margin-bottom:6px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;">🔄 {away_team} Subs</div>
    {#each awaySubs as p}
      <div style="display:flex;align-items:center;gap:7px;padding:4px 0;border-bottom:1px solid #f3f4f6;">
        <img src={p.player_photo} alt={p.player_name}
          style="width:22px;height:22px;border-radius:50%;object-fit:cover;flex-shrink:0;"
          onerror="this.style.display='none'" />
        <span style="background:#fee2e2;color:#b91c1c;font-size:10px;font-weight:700;padding:1px 5px;border-radius:3px;flex-shrink:0;">{p.position_short_code ?? '—'}</span>
        <span style="color:#374151;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{p.player_name}</span>
        {#if p.rating}<span style="font-weight:700;color:{ratingColor(p.rating)};flex-shrink:0;">{p.rating}</span>{/if}
      </div>
    {/each}
  </div>
</div>
{/if}

{/if}

<style>
  .lineup-wrap {
    width: 100%;
  }
  .formation-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 4px 8px;
    font-family: ui-sans-serif, system-ui, sans-serif;
  }
</style>
