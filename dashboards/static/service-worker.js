const CACHE_VERSION = 'v1';
const DATA_CACHE = `data-${CACHE_VERSION}`;
const ASSET_CACHE = `assets-${CACHE_VERSION}`;
const DATA_MAX_AGE = 24 * 60 * 60 * 1000; // 24 hours in ms

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== DATA_CACHE && k !== ASSET_CACHE)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const { request } = e;
  const url = new URL(request.url);

  // Only handle same-origin GET requests
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  if (url.pathname.startsWith('/data/')) {
    e.respondWith(cacheFirstWithExpiry(request, DATA_CACHE, DATA_MAX_AGE));
  } else if (url.pathname.startsWith('/_app/')) {
    e.respondWith(cacheFirst(request, ASSET_CACHE));
  }
  // All other requests (HTML, third-party) go straight to network
});

async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    const cache = await caches.open(cacheName);
    cache.put(request, response.clone());
  }
  return response;
}

async function cacheFirstWithExpiry(request, cacheName, maxAge) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) {
    const cachedAt = cached.headers.get('sw-cached-at');
    if (cachedAt && Date.now() - Number(cachedAt) < maxAge) return cached;
  }
  const response = await fetch(request);
  if (response.ok) {
    const headers = new Headers(response.headers);
    headers.set('sw-cached-at', String(Date.now()));
    const stamped = new Response(await response.arrayBuffer(), {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
    cache.put(request, stamped);
    return stamped;
  }
  return cached ?? response; // fall back to stale cache if fetch fails
}
