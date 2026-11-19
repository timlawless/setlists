// Supabase Edge Function: find-lyrics-link
// Finds LINKS to a song's lyrics page on Genius, so the band can review one and put it in the song's Lyrics link box.
// It NEVER fetches, returns or stores lyrics text: it only reads Genius search metadata (title, artist, page address)
// and never opens the lyrics page itself. This follows the lyrics rule in AGENTS.md.
// Needs one Edge Function secret: GENIUS_ACCESS_TOKEN (a Genius "client access token"). Verify JWT is OFF for this function
// because it checks the caller itself with getUser, exactly like lookup-song.
// Without the secret it answers with a note and no candidates; the app then still shows its own search links.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

// A descriptive User-Agent, as for the other lookups.
const UA = 'SetlistApp/1.0 (+https://timlawless.github.io/setlists/)';

type Candidate = {
  id: string; title: string; artist: string; url: string; host: string; source: string;
  match: 'exact' | 'close' | 'possible';
};

// ---------- ranking (pure: no network) ----------
const norm = (v: unknown): string =>
  String(v ?? '').toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
// Karaoke, tribute and similar re-recordings, and Genius's translation pages, are not what a band wants to read from.
const NOISE = /\b(karaoke|tribute|covers?|instrumental|originally performed|made famous|lullaby|8 bit|backing track|in the style of|remix|translations?|traduccion|traduction|romanized|tradu[cz]ione|ubersetzung)\b/;

// Only an ordinary Genius song page is accepted: https, host exactly genius.com, and not a search or artist page.
export function okGeniusUrl(u: unknown): string {
  try {
    const x = new URL(String(u));
    if (x.protocol !== 'https:' || x.hostname !== 'genius.com') return '';
    if (x.pathname.length < 3 || /^\/(search|artists|albums|tags|videos|a|about)(\/|$)/.test(x.pathname)) return '';
    return `${x.origin}${x.pathname}`;
  } catch { return ''; }
}

export function rankGenius(hits: any[], title: string, artist: string): Candidate[] {
  const q = norm(title), a = norm(artist), seen = new Set<string>();
  const scored = (Array.isArray(hits) ? hits : []).filter((h) => h?.type === 'song' && h?.result).map((h, i) => {
    const r = h.result;
    const url = okGeniusUrl(r.url);
    const t = norm(r.title), who = norm(r.primary_artist?.name);
    let score = 0;
    if (t === q) score += 50; else if (t.startsWith(q) || q.startsWith(t)) score += 25; else if (t.includes(q)) score += 10;
    if (a) { if (who === a) score += 40; else if (who && (who.includes(a) || a.includes(who))) score += 25; }
    if (NOISE.test(t) || NOISE.test(who) || /\bgenius\b/.test(who)) score -= 60;
    if (r.lyrics_state && r.lyrics_state !== 'complete') score = -1; // an unreleased or incomplete page has no lyrics worth linking to
    return { r, url, i, score, exact: t === q && (!a || who === a), close: t === q || t.startsWith(q) || q.startsWith(t) };
  }).filter((x) => x.url && x.score >= 10).sort((x, y) => y.score - x.score || x.i - y.i);
  const out: Candidate[] = [];
  for (const { r, url, exact, close } of scored) {
    if (seen.has(url)) continue; seen.add(url);
    out.push({
      id: `genius:${r.id}`, title: String(r.title ?? '').slice(0, 160), artist: String(r.primary_artist?.name ?? '').slice(0, 160),
      url, host: 'genius.com', source: 'Genius', match: exact ? 'exact' : close ? 'close' : 'possible',
    });
    if (out.length === 3) break;
  }
  return out;
}

// ---------- request handling ----------
type Answer = { candidates: Candidate[]; source: string; note?: string };
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

  let body: { title?: string; artist?: string };
  try { body = await req.json(); } catch { return json({ error: 'Bad request' }, 400); }
  const title = String(body.title ?? '').trim().slice(0, 120);
  const artist = String(body.artist ?? '').trim().slice(0, 120);
  if (!title) return json({ error: 'A title is needed' }, 400);

  const key = Deno.env.get('GENIUS_ACCESS_TOKEN');
  if (!key) return json({ candidates: [], source: 'Genius', note: 'The Genius lookup is not set up yet (the GENIUS_ACCESS_TOKEN secret is missing).' });

  const ck = `${title}|${artist}`.toLowerCase();
  const hit = cache.get(ck);
  if (hit && Date.now() - hit.at < TTL) return json(hit.value);

  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15000);
  try {
    const r = await fetch(`https://api.genius.com/search?q=${encodeURIComponent(`${title} ${artist}`.trim())}`, {
      headers: { Authorization: `Bearer ${key}`, 'User-Agent': UA, Accept: 'application/json' }, signal: ctl.signal,
    });
    if (r.status === 401 || r.status === 403) return json({ candidates: [], source: 'Genius', note: 'Genius did not accept the access token. Check the GENIUS_ACCESS_TOKEN secret.' });
    if (r.status === 429) return json({ candidates: [], source: 'Genius', note: 'Genius is busy. Try again in a few seconds.' });
    if (!r.ok) return json({ error: `Genius answered ${r.status}` }, 502);
    let data: any = null;
    try { data = await r.json(); } catch { /* not JSON */ }
    const candidates = rankGenius(data?.response?.hits ?? [], title, artist);
    const value: Answer = { candidates, source: 'Genius', note: candidates.length ? undefined : 'Genius had no close match for this song.' };
    cache.set(ck, { at: Date.now(), value });
    return json(value);
  } catch (e) {
    return json({ error: (e as Error).name === 'AbortError' ? 'Genius took too long to answer' : (e as Error).message }, 502);
  } finally { clearTimeout(timer); }
});
