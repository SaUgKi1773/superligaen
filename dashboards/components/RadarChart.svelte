<script>
    import { onMount, onDestroy } from 'svelte';
    import * as echarts from 'echarts';

    /** @type {Array<{dimension: string, value: number}>} */
    export let data = [];
    export let name = 'Team';
    export let color = '#236aa4';
    export let height = 380;

    let container;
    let chart;
    let ro;

    function buildOption(rows) {
        const values = rows.map(r => +(r.value) || 0);
        return {
            backgroundColor: 'transparent',
            tooltip: {
                trigger: 'item',
                backgroundColor: '#fff',
                borderColor: '#e5e7eb',
                textStyle: { color: '#374151' },
                formatter: () =>
                    `<div style="font-size:12px;line-height:2;min-width:180px">` +
                    `<div style="font-weight:600;margin-bottom:4px;color:#111">${name}</div>` +
                    rows.map(r =>
                        `<div style="display:flex;justify-content:space-between;gap:20px">` +
                        `<span style="color:#6b7280">${r.dimension}</span>` +
                        `<b style="color:#111">${Math.round(+r.value)}th percentile</b>` +
                        `</div>`
                    ).join('') +
                    `</div>`
            },
            legend: {
                bottom: 0,
                itemGap: 20,
                data: ['League Avg', name],
                textStyle: { color: '#6b7280', fontSize: 12 }
            },
            radar: {
                indicator: rows.map(r => ({ name: r.dimension, max: 100, min: 0 })),
                shape: 'polygon',
                radius: '60%',
                center: ['50%', '47%'],
                splitNumber: 4,
                axisName: {
                    color: '#374151',
                    fontSize: 12,
                    fontWeight: '600'
                },
                splitLine: { lineStyle: { color: '#e5e7eb', width: 1 } },
                splitArea: {
                    areaStyle: {
                        color: [
                            'rgba(249,250,251,0.7)',
                            'rgba(255,255,255,0.7)',
                            'rgba(249,250,251,0.7)',
                            'rgba(255,255,255,0.7)'
                        ]
                    }
                },
                axisLine: { lineStyle: { color: '#d1d5db' } }
            },
            series: [
                {
                    type: 'radar',
                    silent: true,
                    data: [{
                        value: rows.map(() => 50),
                        name: 'League Avg',
                        symbol: 'none',
                        lineStyle: { color: '#9ca3af', type: 'dashed', width: 1.5 },
                        areaStyle: { color: 'transparent' },
                        itemStyle: { color: '#9ca3af' }
                    }]
                },
                {
                    type: 'radar',
                    data: [{
                        value: values,
                        name,
                        symbol: 'circle',
                        symbolSize: 5,
                        lineStyle: { color, width: 2.5 },
                        areaStyle: { color, opacity: 0.22 },
                        itemStyle: { color, borderColor: '#fff', borderWidth: 1.5 }
                    }]
                }
            ]
        };
    }

    $: if (chart && data && data.length > 0) {
        chart.setOption(buildOption(data), true);
    }

    onMount(() => {
        chart = echarts.init(container, null, { renderer: 'canvas' });
        if (data?.length) chart.setOption(buildOption(data));
        ro = new ResizeObserver(() => chart?.resize());
        ro.observe(container);
    });

    onDestroy(() => {
        ro?.disconnect();
        chart?.dispose();
    });
</script>

<div bind:this={container} style="width: 100%; height: {height}px;"></div>
