export const prerender = true;

const webmanifest = {
	name: 'Superliga Analytics',
	short_name: 'Superligaen',
	description: 'Danish Premier Football League — standings, match results, player & team intelligence.',
	start_url: '/',
	display: 'standalone',
	orientation: 'portrait',
	background_color: '#ffffff',
	theme_color: '#1D4ED8',
	icons: [
		{ src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
		{ src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
		{ src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' }
	],
	categories: ['sports', 'entertainment']
};

export const GET = () =>
	new Response(JSON.stringify(webmanifest), {
		headers: { 'Content-Type': 'application/manifest+json' }
	});
