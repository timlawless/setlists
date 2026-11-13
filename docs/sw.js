// Bump VERSION whenever you want installed copies to drop old cached files.
const VERSION = 'band-setlist-1';
const CDN = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const WAIT_MS = 1000; // how long to wait for the network before using the saved copy of an app file
const FILES = ['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png', CDN];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  // Only remove this app's own old caches: github.io hosts other projects on the same origin, and their caches are not ours to delete.
  const ours = (k) => (k.startsWith('band-setlist-') && k !== VERSION) || k.startsWith('setlist-v');
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter(ours).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.hostname.endsWith('supabase.co')) return; // data calls always go to the network
  if (url.origin === location.origin) {
    // app files: network first so updates show up, but never keep the person waiting more than WAIT_MS when a saved copy exists
    e.respondWith((async () => {
      const cache = await caches.open(VERSION);
      const saved = await cache.match(req);
      const net = fetch(req).then((r) => {
        if (r.ok) { cache.put(req, r.clone()).catch(() => {}); return r; }
        return saved || r; // a failed answer (such as a missing page in the middle of an upload) never replaces a good saved copy
      });
      e.waitUntil(net.catch(() => {})); // lets the saved copy finish refreshing in the background after we have answered
      if (!saved) return net; // nothing saved yet (first visit): wait for the network
      const late = new Promise((res) => setTimeout(() => res(saved), WAIT_MS));
      try { return await Promise.race([net, late]); } catch { return saved; } // offline: the saved copy
    })());
  } else if (url.hostname === 'cdn.jsdelivr.net') {
    // the Supabase library: cache first, store any sub-files it loads
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((r) => { if (r.ok) { const c = r.clone(); caches.open(VERSION).then((x) => x.put(req, c)); } return r; })));
  }
});
