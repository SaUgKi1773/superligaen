<script>
  export let data = [];

  const metrics = [
    { key: 'attack_pct',      label: 'Attack',      valueKey: 'goals_per_match',      fmt: v => v != null ? v.toFixed(2) : '—' },
    { key: 'passing_pct',     label: 'Passing',     valueKey: 'pass_accuracy',        fmt: v => v != null ? v.toFixed(1) + '%' : '—' },
    { key: 'efficiency_pct',  label: 'Efficiency',  valueKey: 'shot_conv',            fmt: v => v != null ? v.toFixed(1) + '%' : '—' },
    { key: 'wins_pct',        label: 'Win Rate',    valueKey: 'win_rate',             fmt: v => v != null ? v.toFixed(1) + '%' : '—' },
    { key: 'defense_pct',     label: 'Defense',     valueKey: 'conceded_per_match',   fmt: v => v != null ? v.toFixed(2) : '—' },
    { key: 'possession_pct',  label: 'Possession',  valueKey: 'avg_possession',       fmt: v => v != null ? v.toFixed(1) + '%' : '—' },
  ];

  const W      = 560;
  const H      = 400;
  const cx     = W / 2;
  const cy     = H / 2;
  const r      = 110;
  const n      = metrics.length;
  const rings  = [0.2, 0.4, 0.6, 0.8, 1.0];

  function ang(i)  { return ((360 / n) * i - 90) * Math.PI / 180; }
  function pt(i, s = 1) {
    return { x: cx + r * s * Math.cos(ang(i)), y: cy + r * s * Math.sin(ang(i)) };
  }
  function poly(scales) {
    return scales.map((s, i) => { const p = pt(i, s); return `${p.x},${p.y}`; }).join(' ');
  }
  function anchor(px) { return px < cx - 8 ? 'end' : px > cx + 8 ? 'start' : 'middle'; }

  $: row    = data[0] ?? {};
  $: scales = metrics.map(m => Math.min(Math.max((row[m.key] ?? 0) / 100, 0), 1));
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

    <!-- Data polygon -->
    <polygon points={poly(scales)} fill="#3b82f620" stroke="#3b82f6" stroke-width="2" stroke-linejoin="round" />

    <!-- Data dots -->
    {#each scales as s, i}
      <circle cx={pt(i, s).x} cy={pt(i, s).y} r="4" fill="#3b82f6" stroke="white" stroke-width="1.5" />
    {/each}

    <!-- Labels -->
    {#each metrics as m, i}
      <text
        x={pt(i, 1.48).x}
        y={pt(i, 1.48).y - 8}
        text-anchor={anchor(pt(i, 1.48).x)}
        font-size="10"
        fill="#9ca3af"
        font-family="ui-sans-serif,system-ui,sans-serif"
      >{m.label}</text>
      <text
        x={pt(i, 1.48).x}
        y={pt(i, 1.48).y + 8}
        text-anchor={anchor(pt(i, 1.48).x)}
        font-size="13"
        font-weight="700"
        fill="#111827"
        font-family="ui-sans-serif,system-ui,sans-serif"
      >{m.fmt(row[m.valueKey])}</text>
    {/each}

    <!-- Centre dot -->
    <circle cx={cx} cy={cy} r="3" fill="#374151" />

  </svg>
  <div style="font-size:11px;color:#9ca3af;margin-top:-8px;">Percentile rank vs league (100 = best)</div>
</div>
