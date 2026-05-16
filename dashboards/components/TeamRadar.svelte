<script>
  export let data = [];

  const metrics = [
    { key: 'attack_pct',      label: 'Attack Score'     },
    { key: 'passing_pct',     label: 'Passing Score'    },
    { key: 'efficiency_pct',  label: 'Efficiency Score' },
    { key: 'wins_pct',        label: 'Win Score'        },
    { key: 'defense_pct',     label: 'Defensive Score'  },
    { key: 'possession_pct',  label: 'Possession Score' },
  ];

  function fmtPct(v) { return v != null ? Math.round(v) : '—'; }

  const palette = [
    '#3b82f6', '#ef4444', '#22c55e', '#f59e0b', '#8b5cf6',
    '#ec4899', '#14b8a6', '#f97316', '#6366f1', '#84cc16',
    '#06b6d4', '#a855f7',
  ];

  const W     = 560;
  const H     = 400;
  const cx    = W / 2;
  const cy    = H / 2;
  const r     = 110;
  const n     = metrics.length;
  const rings = [0.2, 0.4, 0.6, 0.8, 1.0];

  let highlighted = null;

  function toggle(teamName) {
    highlighted = highlighted === teamName ? null : teamName;
  }

  function ang(i) { return ((360 / n) * i - 90) * Math.PI / 180; }
  function pt(i, s = 1) {
    return { x: cx + r * s * Math.cos(ang(i)), y: cy + r * s * Math.sin(ang(i)) };
  }
  function poly(scales) {
    return scales.map((s, i) => { const p = pt(i, s); return `${p.x},${p.y}`; }).join(' ');
  }
  function anchor(px) { return px < cx - 8 ? 'end' : px > cx + 8 ? 'start' : 'middle'; }
  function teamScales(row) {
    return metrics.map(m => Math.min(Math.max((row[m.key] ?? 0) / 100, 0), 1));
  }

  $: single   = data.length === 1;
  $: labelRow = highlighted ? (data.find(r => r.team_name === highlighted) ?? data[0] ?? {}) : (data[0] ?? {});
</script>

<div style="display:flex;flex-direction:column;align-items:center;">
  <svg viewBox="0 0 {W} {H}" style="width:100%;max-width:560px;">

    <!-- Background rings -->
    {#each rings as ring, ri}
      <polygon points={poly(metrics.map(() => ring))} fill={ri % 2 === 0 ? '#f9fafb' : 'white'} stroke="#e5e7eb" stroke-width="1" />
    {/each}

    <!-- Axis lines -->
    {#each metrics as _, i}
      <line x1={cx} y1={cy} x2={pt(i).x} y2={pt(i).y} stroke="#d1d5db" stroke-width="1" />
    {/each}

    <!-- Data polygons — rendered in reverse so index-0 team is drawn on top -->
    {#each [...data].reverse() as row, ri}
      {@const idx    = data.length - 1 - ri}
      {@const color  = palette[idx % palette.length]}
      {@const scales = teamScales(row)}
      <polygon points={poly(scales)} fill="{color}18" stroke={color} stroke-width="2" stroke-linejoin="round"
        opacity={highlighted === null ? 1 : highlighted === row.team_name ? 1 : 0.08} />
      {#each scales as s, i}
        <circle cx={pt(i, s).x} cy={pt(i, s).y} r="4" fill={color} stroke="white" stroke-width="1.5"
          opacity={highlighted === null ? 1 : highlighted === row.team_name ? 1 : 0.08} />
      {/each}
    {/each}

    <!-- Axis labels (metric name always; value when single team or one highlighted) -->
    {#each metrics as m, i}
      <text
        x={pt(i, 1.48).x}
        y={pt(i, 1.48).y - 8}
        text-anchor={anchor(pt(i, 1.48).x)}
        font-size="10"
        fill="#9ca3af"
        font-family="ui-sans-serif,system-ui,sans-serif"
      >{m.label}</text>
      {#if single || highlighted}
      <text
        x={pt(i, 1.48).x}
        y={pt(i, 1.48).y + 8}
        text-anchor={anchor(pt(i, 1.48).x)}
        font-size="13"
        font-weight="700"
        fill="#111827"
        font-family="ui-sans-serif,system-ui,sans-serif"
      >{fmtPct(labelRow[m.key])}</text>
      {/if}
    {/each}

    <!-- Centre dot -->
    <circle cx={cx} cy={cy} r="3" fill="#374151" />

  </svg>

  <!-- Legend — only when more than one team -->
  {#if data.length > 1}
  <div style="display:flex;flex-wrap:wrap;gap:6px 14px;justify-content:center;margin-top:2px;">
    {#each data as row, i}
    <div
      on:click={() => toggle(row.team_name)}
      style="display:flex;align-items:center;gap:5px;font-size:11px;cursor:pointer;transition:opacity 0.15s;
             opacity:{highlighted === null || highlighted === row.team_name ? 1 : 0.35};
             color:{highlighted === row.team_name ? palette[i % palette.length] : '#374151'};
             font-weight:{highlighted === row.team_name ? '700' : '400'};"
    >
      <div style="width:10px;height:10px;border-radius:50%;background:{palette[i % palette.length]};flex-shrink:0;"></div>
      {row.team_name}
    </div>
    {/each}
  </div>
  {/if}

</div>
