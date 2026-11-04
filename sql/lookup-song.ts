// Supabase Edge Function: lookup-song
// Finds tempo, key and time signature for a song using the GetSongBPM API.
// The API key stays here as a secret (GETSONGBPM_API_KEY); the app never sees it.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const API = 'https://api.getsongbpm.com';

// "4" becomes "4/4"; anything that already has a slash is kept
const sig = (v: unknown): string => {
  const s = String(v ?? '').trim();
  if (!s) return '';
  return s.includes('/') ? s : /^\d+$/.test(s) ? `${s}/4` : s;
};
// the API describes the artist as an object (sometimes wrapped in an array)
const artistName = (x: any): string => (Array.isArray(x?.artist) ? x.artist[0] : x?.artist)?.name ?? '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Use POST' }, 405);

  // Only signed-in users of the app may use this function
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: auth, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !auth?.user) return json({ error: 'Please sign in first' }, 401);

  const apiKey = Deno.env.get('GETSONGBPM_API_KEY');
  if (!apiKey) return json({ error: 'Lookup is not set up yet (missing API key secret)' }, 500);

  let body: { title?: string; artist?: string };
  try { body = await req.json(); } catch { return json({ error: 'Bad request' }, 400); }
  const title = String(body.title ?? '').trim().slice(0, 120);
  const artist = String(body.artist ?? '').trim().slice(0, 120);
  if (!title) return json({ error: 'A title is needed' }, 400);

  const get = async (path: string, params: Record<string, string>) => {
    const r = await fetch(`${API}${path}?${new URLSearchParams(params)}`, {
      headers: { 'X-API-KEY': apiKey, Accept: 'application/json' },
    });
    if (!r.ok) throw new Error(`GetSongBPM answered ${r.status}`);
    return await r.json();
  };

  try {
    let results: any[] = [];
    if (artist) {
      // title and artist given: one call returns tempo, key and time signature
      const d = await get('/search/', { type: 'both', lookup: `song:${title} artist:${artist}`, limit: '6' });
      const rows: any[] = Array.isArray(d?.search) ? d.search : [];
      results = rows.map((r) => ({
        id: r.song_id, title: r.song_title, artist: artistName(r),
        tempo: Number(r.tempo) || null, time_sig: sig(r.time_sig), key_of: r.key_of ?? '',
      }));
    } else {
      // title only: find the matching songs (different artists), then fetch each one's details
      const d = await get('/search/', { type: 'song', lookup: title, limit: '6' });
      const rows: any[] = Array.isArray(d?.search) ? d.search : [];
      const details = await Promise.all(rows.map(async (r) => {
        try {
          const s = (await get('/song/', { id: String(r.id) }))?.song;
          return s ? {
            id: s.id, title: s.title, artist: artistName(s),
            tempo: Number(s.tempo) || null, time_sig: sig(s.time_sig), key_of: s.key_of ?? '',
          } : null;
        } catch { return null; }
      }));
      results = details.filter(Boolean);
    }
    return json({ results });
  } catch (e) {
    return json({ error: (e as Error).message }, 502);
  }
});
