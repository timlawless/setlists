// Supabase Edge Function: lookup-song
// Finds tempo and key (and the time signature when a source has it) for a song.
//   Source 1: GetSongBPM, used only when the secret GETSONGBPM_API_KEY is set and it answers.
//   Source 2: Song Finder (songfinder.dev), free and without a key, used when source 1 is missing or has nothing.
// Every match carries a confidence level so the band can judge it. The band's own values always win in the app.
// Song Finder works in two steps so the person chooses the right recording: a search returns a ranked list of
// candidates (title, artist, album, year), and tapping one asks for that recording's tempo and key.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

// A descriptive User-Agent is required: Song Finder sits behind bot rules that refuse anonymous clients.
const UA = 'SetlistApp/1.0 (+https://timlawless.github.io/setlists/)';

type Candidate = { id: string; title: string; artist: string; album: string; year: string; exact: boolean };
type Match = {
  id: string; title: string; artist: string; tempo: number | null; time_sig: string; key_of: string;
  source: string; confidence: 'high' | 'medium' | 'check'; note?: string;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function getJson(url: string, headers: Record<string, string> = {}, ms = 20000): Promise<{ status: number; body: any }> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json', ...headers }, signal: ctl.signal });
    let body: any = null;
    try { body = await r.json(); } catch { /* not JSON */ }
    return { status: r.status, body };
  } finally { clearTimeout(timer); }
}

// "4" becomes "4/4"; anything with a slash is kept
const sig = (v: unknown): string => {
  const s = String(v ?? '').trim();
  if (!s) return '';
  return s.includes('/') ? s : /^\d+$/.test(s) ? `${s}/4` : s;
};
const artistName = (x: any): string => (Array.isArray(x?.artist) ? x.artist[0] : x?.artist)?.name ?? '';

// ---------- Source 1: GetSongBPM ----------
async function viaGetSongBpm(title: string, artist: string, apiKey: string): Promise<Match[]> {
  const API = 'https://api.getsongbpm.com'; // base URL as listed on getsongbpm.com/api
  const get = async (path: string, params: Record<string, string>) => {
    const r = await getJson(`${API}${path}?${new URLSearchParams(params)}`, { 'X-API-KEY': apiKey });
    if (r.status >= 400) throw new Error(`GetSongBPM answered ${r.status}`);
    return r.body;
  };
  const mk = (id: unknown, t: string, a: string, tempo: unknown, ts: unknown, key: unknown): Match => ({
    id: `gsb:${id}`, title: t, artist: a, tempo: Number(tempo) || null, time_sig: sig(ts), key_of: String(key ?? ''),
    source: 'GetSongBPM', confidence: 'medium',
  });
  if (artist) {
    const d = await get('/search/', { type: 'both', lookup: `song:${title} artist:${artist}`, limit: '6' });
    const rows: any[] = Array.isArray(d?.search) ? d.search : [];
    return rows.map((r) => mk(r.song_id, r.song_title, artistName(r), r.tempo, r.time_sig, r.key_of));
  }
  const d = await get('/search/', { type: 'song', lookup: title, limit: '6' });
  const rows: any[] = Array.isArray(d?.search) ? d.search : [];
  const details = await Promise.all(rows.map(async (r) => {
    try {
      const s = (await get('/song/', { id: String(r.id) }))?.song;
      return s ? mk(s.id, s.title, artistName(s), s.tempo, s.time_sig, s.key_of) : null;
    } catch { return null; }
  }));
  return details.filter(Boolean) as Match[];
}

// ---------- Source 2: Song Finder ----------
const SF = 'https://songfinder.dev';
const isIsrc = (v: unknown) => typeof v === 'string' && /^[A-Za-z0-9]{12}$/.test(v);
// "B Minor" becomes "Bm", "F# Major" becomes "F#"; anything else is kept as it came
const keyShort = (name?: string): string => {
  const m = /^([A-G][#b♯♭]?)\s+(major|minor)$/i.exec((name || '').trim());
  return m ? m[1].replace('♯', '#').replace('♭', 'b') + (m[2].toLowerCase() === 'minor' ? 'm' : '') : (name || '');
};
async function sfCall(url: string): Promise<any> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const r = await getJson(url);
    if (r.status === 429) { if (attempt === 0) { await sleep(3000); continue; } throw new Error('Song Finder is busy. Try again in a few seconds.'); }
    if (r.status >= 400 || !r.body || r.body.code !== 0) throw new Error(r.body?.message || `Song Finder answered ${r.status}`);
    return r.body.data;
  }
  throw new Error('Song Finder is busy. Try again in a few seconds.');
}
const norm = (v: unknown): string =>
  String(v ?? '').toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
// words that usually mean a karaoke track, a tribute or another kind of re-recording
const NOISE = /\b(karaoke|tribute|covers?|instrumental|originally performed|made famous|lullaby|8 bit|backing track|in the style of|piano version|remix)\b/;

// Rank what Song Finder found: the exact title first, then the artist the person typed, and re-recordings last.
function rank(found: any[], title: string, artist: string): Candidate[] {
  const q = norm(title), a = norm(artist), seen = new Set<string>();
  const scored = found.filter((c) => isIsrc(c?.isrc)).map((c, i) => {
    const t = norm(c.title), who = norm(c.artist);
    let score = 0;
    if (t === q) score += 50; else if (t.startsWith(q) || q.startsWith(t)) score += 25; else if (t.includes(q)) score += 10;
    if (a) { if (who === a) score += 40; else if (who && (who.includes(a) || a.includes(who))) score += 25; }
    if (NOISE.test(t) || NOISE.test(norm(c.album)) || NOISE.test(who)) score -= 40;
    return { c, i, score, exact: t === q };
  }).sort((x, y) => y.score - x.score || x.i - y.i);
  const out: Candidate[] = [];
  for (const { c, exact } of scored) {
    const k = `${norm(c.title)}|${norm(c.artist)}`;
    if (seen.has(k)) continue; seen.add(k);
    out.push({ id: `sf:${c.isrc}`, title: String(c.title ?? ''), artist: String(c.artist ?? ''), album: String(c.album ?? ''), year: String(c.releaseYear ?? ''), exact });
    if (out.length === 8) break;
  }
  return out;
}
async function songFinderSearch(title: string, artist: string): Promise<Candidate[]> {
  const found = await sfCall(`${SF}/api/track/search?q=${encodeURIComponent(`${title} ${artist}`.trim())}`);
  return rank(Array.isArray(found) ? found : [], title, artist);
}
// Tempo and key for one chosen recording
async function songFinderAnalyse(isrc: string): Promise<Match | null> {
  const d = await sfCall(`${SF}/api/track/detail?isrc=${encodeURIComponent(isrc)}`);
  const f = d?.features, primary = Number(f?.tempo);
  if (!(primary > 0)) return null; // no analysis for this recording
  const cross = Number(d?.tempoCrossCheck);
  let confidence: Match['confidence'] = 'medium', note: string | undefined;
  if (cross > 0) {
    if (Math.abs(primary - cross) > 3) {
      confidence = 'check';
      note = `A second source reads ${Math.round(cross)} BPM. One of the two is probably counting half or double time, so check it against the recording.`;
    } else confidence = 'high';
  }
  return {
    id: `sf:${isrc}`, title: String(d?.track?.title ?? ''), artist: String(d?.track?.artist ?? ''),
    tempo: Math.round(primary), time_sig: '', key_of: keyShort(f?.key?.name), source: 'Song Finder', confidence, note,
  };
}

// ---------- Request handling ----------
type Answer = { results: Match[]; candidates: Candidate[]; source: string; note?: string };
const cache = new Map<string, { at: number; value: Answer }>();
const TTL = 10 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Use POST' }, 405);

  // Only signed-in users of the app may use this function
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: auth, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !auth?.user) return json({ error: 'Please sign in first' }, 401);

  let body: { title?: string; artist?: string; isrc?: string };
  try { body = await req.json(); } catch { return json({ error: 'Bad request' }, 400); }

  // Step 2: tempo and key for one chosen Song Finder recording
  if (body.isrc !== undefined) {
    const isrc = String(body.isrc).replace(/^sf:/, '').trim();
    if (!isIsrc(isrc)) return json({ error: 'That recording id is not valid' }, 400);
    const hit = cache.get(`isrc:${isrc}`);
    if (hit && Date.now() - hit.at < TTL) return json(hit.value);
    try {
      const m = await songFinderAnalyse(isrc);
      const value: Answer = m ? { results: [m], candidates: [], source: 'Song Finder' }
        : { results: [], candidates: [], source: 'Song Finder', note: 'No tempo and key analysis is available for that recording.' };
      if (m) cache.set(`isrc:${isrc}`, { at: Date.now(), value });
      return json(value);
    } catch (e) { return json({ error: (e as Error).message }, 502); }
  }

  // Step 1: search
  const title = String(body.title ?? '').trim().slice(0, 120);
  const artist = String(body.artist ?? '').trim().slice(0, 120);
  if (!title) return json({ error: 'A title is needed' }, 400);

  const ck = `q:${title}|${artist}`.toLowerCase();
  const hit = cache.get(ck);
  if (hit && Date.now() - hit.at < TTL) return json(hit.value);

  let results: Match[] = [], candidates: Candidate[] = [], source = '', problem = '';
  const apiKey = Deno.env.get('GETSONGBPM_API_KEY');
  if (apiKey) {
    try { results = await viaGetSongBpm(title, artist, apiKey); source = 'GetSongBPM'; }
    catch (e) { console.log('GetSongBPM failed:', (e as Error).message); }
  }
  if (!results.length) {
    try { candidates = await songFinderSearch(title, artist); source = 'Song Finder'; }
    catch (e) { problem = (e as Error).message; }
  }
  if (!results.length && !candidates.length && problem) return json({ error: problem }, 502);
  const value: Answer = { results, candidates, source };
  if (results.length || candidates.length) cache.set(ck, { at: Date.now(), value });
  return json(value);
});
