'use strict';
const VERSION = '1';
const $ = (id) => document.getElementById(id);
const ua = navigator.userAgent;
const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isAndroid = /Android/.test(ua);
const platformName = isIOS ? 'iPhone or iPad (iOS)' : isAndroid ? 'Android' : 'Other (' + (navigator.platform || 'unknown') + ')';
const standalone = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

// ---------- event log ----------
const log = [];
function note(msg) {
  log.unshift(new Date().toLocaleTimeString() + '  ' + msg);
  if (log.length > 80) log.pop();
  const el = $('log'); if (el) el.textContent = log.join('\n');
}

/* BEGIN BeatScheduler (copy of core/src/metronome.ts, in plain JS) */
function flashAllowed(bpm, beatIndex) { return bpm <= 180 || beatIndex === 0; }
class BeatScheduler {
  constructor(o) { this.o = o; this.bpm = o.bpm; this.beat = 0; this.next = 0; this.running = false; }
  start() { this.running = true; this.beat = 0; this.next = this.o.now(); this.tick(); }
  stop() { this.running = false; }
  setBpm(bpm) { this.bpm = Math.max(40, Math.min(240, bpm)); }
  tick() {
    if (!this.running) return;
    const horizon = this.o.now() + (this.o.lookaheadMs == null ? 100 : this.o.lookaheadMs);
    const per = this.o.beatsPerBar || 4;
    while (this.next < horizon) {
      this.o.onBeat({ beat: this.beat, atMs: this.next });
      this.next += 60000 / this.bpm;
      this.beat = (this.beat + 1) % per;
    }
  }
}
/* END BeatScheduler */

// ---------- 1. install and offline ----------
let deferredPrompt = null, swState = 'not supported';
$('ver').textContent = VERSION;
$('st-platform').textContent = platformName;
$('installHint').textContent = isIOS
  ? 'On iPhone and iPad: open this page in Safari, tap the Share button, then Add to Home Screen. Then open it from the new icon.'
  : isAndroid ? 'On Android: use the Install button below if it appears, or the browser menu, then Install app. Then open it from the new icon.'
  : 'Use the browser menu to install the app.';
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); deferredPrompt = e; $('installBtn').hidden = false; note('install prompt available'); });
window.addEventListener('appinstalled', () => { note('app installed'); $('installBtn').hidden = true; });
$('installBtn').onclick = async () => { if (!deferredPrompt) return; deferredPrompt.prompt(); const r = await deferredPrompt.userChoice; note('install choice: ' + r.outcome); deferredPrompt = null; $('installBtn').hidden = true; };
window.addEventListener('online', () => { note('online'); renderStatus(); });
window.addEventListener('offline', () => { note('offline'); renderStatus(); });

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').then(() => { note('service worker registered'); }).catch((e) => { swState = 'failed: ' + e.message; note('service worker failed: ' + e.message); });
  navigator.serviceWorker.ready.then(() => { note('service worker ready'); renderStatus(); });
}

// ---------- 2. storage ----------
function idb() {
  return new Promise((res, rej) => { const r = indexedDB.open('pwa-test', 1); r.onupgradeneeded = () => r.result.createObjectStore('kv'); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); });
}
async function kv(op, key, val) {
  const db = await idb();
  return new Promise((res, rej) => {
    const tx = db.transaction('kv', op === 'get' ? 'readonly' : 'readwrite'); const st = tx.objectStore('kv');
    const rq = op === 'get' ? st.get(key) : st.put(val, key); rq.onsuccess = () => res(rq.result); rq.onerror = () => rej(rq.error);
  });
}
const visits = { first: null, count: null, lsFirst: null, lsCount: null, err: '' };
async function recordVisit() {
  try {
    let first = await kv('get', 'first'); let count = (await kv('get', 'count')) || 0;
    if (!first) { first = Date.now(); await kv('put', 'first', first); }
    count += 1; await kv('put', 'count', count);
    visits.first = first; visits.count = count;
  } catch (e) { visits.err = 'IndexedDB failed: ' + e.message; note(visits.err); }
  try {
    let lf = Number(localStorage.getItem('first')) || 0; if (!lf) { lf = Date.now(); localStorage.setItem('first', lf); }
    const lc = (Number(localStorage.getItem('count')) || 0) + 1; localStorage.setItem('count', lc);
    visits.lsFirst = lf; visits.lsCount = lc;
  } catch (e) { note('localStorage failed: ' + e.message); }
  renderStatus();
}
async function storageInfo() {
  const out = {};
  try { if (navigator.storage && navigator.storage.persisted) out.persisted = await navigator.storage.persisted(); } catch (e) {}
  try { if (navigator.storage && navigator.storage.estimate) { const e = await navigator.storage.estimate(); out.quotaMB = Math.round(e.quota / 1048576); out.usedKB = Math.round(e.usage / 1024); } } catch (e) {}
  return out;
}
$('persistBtn').onclick = async () => {
  if (!(navigator.storage && navigator.storage.persist)) { note('persist() not supported'); return; }
  const ok = await navigator.storage.persist(); note('persist() returned ' + ok); renderStatus();
};

// ---------- 3. metronome ----------
const AC = window.AudioContext || window.webkitAudioContext;
let ctx = null, sched = null, timer = null, running = false, silentEl = null;
const stats = { t0: 0, a0: 0, beats: 0, late: 0, maxGap: 0, big: 0, last: 0 };
let bpm = 120;
function silentWavUrl() {
  const n = 8000, b = new Uint8Array(44 + n), v = new DataView(b.buffer);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) b[o + i] = s.charCodeAt(i); };
  w(0, 'RIFF'); v.setUint32(4, 36 + n, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, 8000, true); v.setUint32(28, 8000, true); v.setUint16(32, 1, true); v.setUint16(34, 8, true); w(36, 'data'); v.setUint32(40, n, true);
  b.fill(128, 44);
  return URL.createObjectURL(new Blob([b], { type: 'audio/wav' }));
}
function click(t, accent) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.value = accent ? 1200 : 800;
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.5, t + 0.002); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
  o.connect(g); g.connect(ctx.destination); o.start(t); o.stop(t + 0.06);
}
function flash(strong) { const f = $('flash'); f.style.opacity = strong ? '0.85' : '0.55'; setTimeout(() => { f.style.opacity = '0'; }, 110); }
function onBeat(e) {
  const at = e.atMs / 1000;
  if (at < ctx.currentTime - 0.005) stats.late++;
  stats.beats++;
  if ($('soundOn').checked) click(at, e.beat === 0);
  if ($('flashOn').checked && flashAllowed(bpm, e.beat)) setTimeout(() => flash(e.beat === 0), Math.max(0, e.atMs - ctx.currentTime * 1000));
}
async function startMetro() {
  if (!AC) { note('Web Audio not supported'); return; }
  if (!ctx) { ctx = new AC(); ctx.onstatechange = () => { note('audio state: ' + ctx.state); renderStatus(); }; }
  try { await ctx.resume(); } catch (e) { note('resume failed: ' + e.message); }
  if ($('silentFix').checked) { if (!silentEl) { silentEl = new Audio(silentWavUrl()); silentEl.loop = true; } silentEl.play().catch((e) => note('silent audio failed: ' + e.message)); }
  Object.assign(stats, { t0: performance.now(), a0: ctx.currentTime, beats: 0, late: 0, maxGap: 0, big: 0, last: performance.now() });
  sched = new BeatScheduler({ bpm, lookaheadMs: 150, now: () => ctx.currentTime * 1000, onBeat });
  sched.start();
  timer = setInterval(() => {
    const n = performance.now(), gap = n - stats.last; stats.last = n;
    if (gap > stats.maxGap) stats.maxGap = gap;
    if (gap > 500) { stats.big++; note('timer gap ' + Math.round(gap) + ' ms'); }
    sched.tick(); renderMetro();
  }, 25);
  running = true; $('metroBtn').textContent = 'Stop'; note('metronome started at ' + bpm + ' BPM');
}
function stopMetro() {
  if (sched) sched.stop(); clearInterval(timer); timer = null; running = false;
  if (silentEl) silentEl.pause();
  $('metroBtn').textContent = 'Start'; note('metronome stopped'); renderMetro();
}
$('metroBtn').onclick = () => (running ? stopMetro() : startMetro());
$('bpm').oninput = () => { bpm = Number($('bpm').value); $('bpmv').textContent = bpm; if (sched) sched.setBpm(bpm); };
function renderMetro() {
  if (!ctx) return;
  const behind = running ? (performance.now() - stats.t0) - (ctx.currentTime - stats.a0) * 1000 : 0;
  $('m-state').textContent = ctx.state + (running ? ' (metronome on)' : ' (metronome off)');
  $('m-beats').textContent = stats.beats; $('m-late').textContent = stats.late;
  $('m-gap').textContent = Math.round(stats.maxGap) + ' ms'; $('m-big').textContent = stats.big;
  $('m-drift').textContent = Math.round(Math.max(0, behind)) + ' ms';
  const bl = ctx.baseLatency, ol = ctx.outputLatency;
  $('m-lat').textContent = 'base ' + (bl == null ? 'n/a' : Math.round(bl * 1000) + ' ms') + ', output ' + (ol == null ? 'n/a' : Math.round(ol * 1000) + ' ms') + ', ' + ctx.sampleRate + ' Hz';
}

// ---------- 4. wake lock ----------
let wl = null, wlSince = 0, wlWanted = false;
$('w-sup').textContent = 'wakeLock' in navigator ? 'yes' : 'no';
async function acquireWL() {
  try {
    wl = await navigator.wakeLock.request('screen'); wlSince = Date.now(); note('wake lock acquired');
    wl.addEventListener('release', () => { note('wake lock released'); renderStatus(); });
  } catch (e) { note('wake lock failed: ' + e.name + ' ' + e.message); }
  renderStatus();
}
$('wlBtn').onclick = async () => {
  if (!('wakeLock' in navigator)) { note('wake lock not supported'); return; }
  if (wlWanted) { wlWanted = false; if (wl) await wl.release(); $('wlBtn').textContent = 'Keep screen awake'; return; }
  wlWanted = true; $('wlBtn').textContent = 'Stop keeping awake'; await acquireWL();
};
document.addEventListener('visibilitychange', () => {
  note('page ' + document.visibilityState);
  if (document.visibilityState === 'visible' && wlWanted && (!wl || wl.released)) acquireWL();
});

// ---------- 5. screen ----------
function renderScreen() {
  $('s-size').textContent = innerWidth + ' x ' + innerHeight + ' px, pixel ratio ' + devicePixelRatio;
  $('s-orient').textContent = (screen.orientation && screen.orientation.type) || (innerWidth > innerHeight ? 'landscape' : 'portrait');
  $('s-layout').textContent = innerWidth >= 768 ? 'tablet layout (two panes)' : 'phone layout (one column)';
  $('s-touch').textContent = matchMedia('(pointer: coarse)').matches ? 'touch screen' : 'mouse or trackpad';
}
addEventListener('resize', renderScreen); addEventListener('orientationchange', renderScreen);

// ---------- status ----------
async function renderStatus() {
  const inst = standalone();
  $('st-installed').innerHTML = inst ? '<span class="ok">yes</span>' : '<span class="bad">no (open it from the home screen icon)</span>';
  if ('serviceWorker' in navigator) swState = navigator.serviceWorker.controller ? 'active and controlling this page' : 'registered; reload once so it controls the page';
  $('st-sw').textContent = swState;
  $('st-online').textContent = navigator.onLine ? 'online' : 'OFFLINE';
  const dt = (t) => (t ? new Date(t).toLocaleString() + ' (' + Math.floor((Date.now() - t) / 86400000) + ' days ago)' : 'unknown');
  $('st-first').textContent = visits.err || 'IndexedDB: ' + dt(visits.first) + '\nlocalStorage: ' + dt(visits.lsFirst);
  $('st-first').style.whiteSpace = 'pre-line';
  $('st-count').textContent = 'IndexedDB ' + visits.count + ', localStorage ' + visits.lsCount;
  const st = await storageInfo();
  $('st-persist').textContent = st.persisted == null ? 'not reported' : st.persisted ? 'yes' : 'no (the browser may clear it)';
  $('st-space').textContent = st.quotaMB == null ? 'not reported' : st.usedKB + ' KB used of about ' + st.quotaMB + ' MB';
  $('w-state').textContent = wl && !wl.released ? 'ON for ' + Math.round((Date.now() - wlSince) / 1000) + ' s' : wlWanted ? 'requested, not active' : 'off';
  renderScreen();
}

// ---------- 7. report ----------
async function buildReport() {
  const st = await storageInfo();
  const answers = [...document.querySelectorAll('select[data-q]')].map((s) => '  ' + s.dataset.q + ': ' + s.value);
  return [
    'Setlist PWA test v' + VERSION, new Date().toString(), ua, 'Device: ' + platformName,
    'Installed (standalone): ' + standalone(), 'Install prompt seen: ' + !!deferredPrompt, 'Service worker: ' + swState, 'Online: ' + navigator.onLine,
    'Storage: ' + JSON.stringify(st), 'First opened (IndexedDB / localStorage): ' + visits.first + ' / ' + visits.lsFirst,
    'Times opened (IndexedDB / localStorage): ' + visits.count + ' / ' + visits.lsCount,
    'Wake lock supported: ' + ('wakeLock' in navigator) + ', now: ' + $('w-state').textContent,
    'Audio: ' + (ctx ? ctx.state : 'not started') + ', beats ' + stats.beats + ', late ' + stats.late + ', longest timer gap ' + Math.round(stats.maxGap) + ' ms, gaps over 0.5 s ' + stats.big + ', ' + $('m-drift').textContent + ' behind, ' + $('m-lat').textContent,
    'Screen: ' + $('s-size').textContent + ', ' + $('s-orient').textContent + ', ' + $('s-layout').textContent,
    '', 'Answers:', ...answers, '', 'Event log:', ...log
  ].join('\n');
}
$('reportBtn').onclick = async () => {
  const text = await buildReport(); const box = $('reportBox'); box.value = text;
  try { await navigator.clipboard.writeText(text); $('reportMsg').textContent = 'Copied. Paste it into your chat.'; box.hidden = true; }
  catch (e) { box.hidden = false; box.focus(); box.select(); $('reportMsg').textContent = 'Select all in the box below and copy it.'; }
};

recordVisit(); renderStatus(); setInterval(renderStatus, 2000);
