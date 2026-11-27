// Supabase Edge Function: find-progression-link
// Returns direct Songsterr song/tab pages only. It does not fetch or return tab notation.
// Songsterr's keyless JSON search endpoint is unofficial; keep requests small and handle outages gracefully.
// Deploy as find-progression-link with Verify JWT OFF; this function validates the signed-in user itself.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const UA = 'SetlistApp/1.0 (+https://timlawless.github.io/setlists/)';
type Candidate = { id: string; title: string; artist: string; url: string; track: string };

const norm = (v: unknown): string =>
  String(v ?? '').toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
const slug = (v: unknown): string => norm(v).replace(/\s+/g, '-').replace(/^-|-$/g, '');
const scorePart = (actual: string, wanted: string): number =>
  actual === wanted ? 50 : actual.startsWith(wanted) || wanted.startsWith(actual) ? 25 : actual.includes(wanted) ? 10 : 0;

function rankSongs(rows: any[], title: string, artist: string, instrument: string): Candidate[] {
  const wantedTitle = norm(title), wantedArtist = norm(artist), seen = new Set<string>();
  return (Array.isArray(rows) ? rows : []).map((song) => {
    const songTitle = String(song?.title ?? ''), songArtist = String(song?.artist ?? '');
    const tracks = Array.isArray(song?.tracks) ? song.tracks : [];
    const matchingTracks = tracks.filter((track: any) => {
      const name = norm(track?.instrument ?? '');
      return instrument === 'bass' ? name.includes('bass') : name.includes('guitar');
    });
    const track = matchingTracks[0];
    const score = scorePart(norm(songTitle), wantedTitle) + scorePart(norm(songArtist), wantedArtist);
    const id = String(song?.songId ?? song?.id ?? '');
    return { songTitle, songArtist, track, id, score };
  }).filter((x) => x.id && x.track && x.score >= 60)
    .sort((a, b) => b.score - a.score)
    .filter((x) => {
      const key = x.id;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 4).map((x) => ({
      id: `songsterr:${x.id}`, title: x.songTitle, artist: x.songArtist,
      track: String(x.track?.instrument ?? x.track?.name ?? (instrument === 'bass' ? 'Bass' : 'Guitar')),
      url: `https://www.songsterr.com/a/wsa/${slug(x.songArtist)}-${slug(x.songTitle)}-tab-s${x.id}`,
    }));
}

const cache = new Map<string, { at: number; candidates: Candidate[] }>();
const TTL = 10 * 60 * 1000;
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Use POST' }, 405);

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: auth, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !auth?.user) return json({ error: 'Please sign in first' }, 401);

  let body: { title?: string; artist?: string; instrument?: string };
  try { body = await req.json(); } catch { return json({ error: 'Bad request' }, 400); }
  const title = String(body.title ?? '').trim().slice(0, 120);
  const artist = String(body.artist ?? '').trim().slice(0, 120);
  const instrument = body.instrument === 'bass' ? 'bass' : 'guitar';
  if (!title || !artist) return json({ candidates: [], note: 'A song title and artist are needed.' });

  const key = `${instrument}|${title}|${artist}`.toLowerCase();
  const cached = cache.get(key);
  if (cached && Date.now() - cached.at < TTL) return json({ candidates: cached.candidates, source: 'Songsterr' });

  const query = encodeURIComponent(`${artist} ${title}`);
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 12000);
  try {
    const response = await fetch(`https://www.songsterr.com/api/songs?pattern=${query}&size=20`, {
      headers: { 'User-Agent': UA, Accept: 'application/json' }, signal: ctl.signal,
    });
    if (!response.ok) return json({ candidates: [], source: 'Songsterr', note: `Songsterr search returned ${response.status}; use the search links below instead.` });
    const rows = await response.json();
    const candidates = rankSongs(rows, title, artist, instrument);
    cache.set(key, { at: Date.now(), candidates });
    return json({ candidates, source: 'Songsterr', note: candidates.length ? undefined : 'No close Songsterr tab match with the requested instrument was found.' });
  } catch (error) {
    return json({ candidates: [], source: 'Songsterr', note: (error as Error).name === 'AbortError' ? 'Songsterr took too long to answer.' : 'Songsterr is temporarily unavailable.' });
  } finally { clearTimeout(timer); }
});
