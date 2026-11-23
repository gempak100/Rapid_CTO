// Simpan fail apps supaya boleh dibuka tanpa internet. Bila ada internet, ambil versi terbaru dulu.
const CACHE = 'jadual-kerja-v4';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))); self.clients.claim(); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return;
  const fresh = e.request.mode === 'navigate' || /\/(index\.html)?$/.test(url.pathname) || url.pathname.endsWith('.json');
  // halaman & roster: sentiasa ambil versi terbaru dari internet (elak versi lama tersimpan)
  const req = fresh ? fetch(url.origin + url.pathname, { cache: 'no-store', credentials: 'same-origin' }) : fetch(e.request);
  const key = fresh ? url.origin + url.pathname : e.request;
  e.respondWith(req.then(r => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(key, copy)); } return r; })
    .catch(() => caches.match(key, { ignoreSearch: true }).then(r => r || caches.match('./index.html'))));
});
