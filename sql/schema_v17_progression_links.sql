-- Setlists SQL v17: separate progression links from text notes.
-- Run in the Supabase SQL Editor after v14, v15 and v16, and BEFORE deploying the matching app/index.html.
-- Safe to run more than once. No rows, permissions or existing history are deleted.

alter table public.songs add column if not exists chords_url text;
alter table public.songs add column if not exists bassline_url text;

-- Preserve legacy links, but stop treating the text fields as link storage.
update public.songs
   set chords_url = coalesce(nullif(chords_url, ''), btrim(chords)),
       chords = ''
 where deleted_at is null
   and btrim(coalesce(chords, '')) ~* '^https?://[^[:space:]]+$';

update public.songs
   set bassline_url = coalesce(nullif(bassline_url, ''), btrim(root_notes)),
       root_notes = ''
 where deleted_at is null
   and btrim(coalesce(root_notes, '')) ~* '^https?://[^[:space:]]+$';

-- Setlists schema v17: separate saved progression links from the band's editable chord and bass notes.
-- Apply after schema v14, v15 and v16 and before uploading the matching app/index.html. Safe to run more than once.
-- Existing HTTP(S) URLs in songs.chords and songs.root_notes are moved to chords_url and bassline_url;
-- the text fields are cleared only when they contain a URL, preserving any actual notes.
-- The offline RPC is updated to accept the two new song fields while retaining v14 idempotency and RLS behaviour.
--
-- The RPC is SECURITY INVOKER. Writes to songs, setlist_songs and song_links therefore
-- continue to use the caller's existing grants and row-level security policies. The
-- private-to-each-user receipt table is also protected by RLS. Its insert policy is
-- enabled only while the RPC is running in the current transaction.

create table if not exists public.offline_operation_receipts (
  user_id      uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  operation    jsonb not null,
  result       jsonb not null,
  created_at   timestamptz not null default now(),
  primary key (user_id, operation_id)
);

alter table public.offline_operation_receipts enable row level security;
drop policy if exists offline_operation_receipts_select on public.offline_operation_receipts;
create policy offline_operation_receipts_select on public.offline_operation_receipts
  for select to authenticated using (user_id = auth.uid());
drop policy if exists offline_operation_receipts_insert on public.offline_operation_receipts;
create policy offline_operation_receipts_insert on public.offline_operation_receipts
  for insert to authenticated with check (
    user_id = auth.uid() and current_setting('app.offline_operation_rpc', true) = 'on'
  );
revoke all on public.offline_operation_receipts from public, anon;
grant select, insert on public.offline_operation_receipts to authenticated;

create or replace function public.apply_offline_operation(p_operation_id uuid, p_operation jsonb)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_existing public.offline_operation_receipts%rowtype;
  v_type text;
  v_row jsonb;
  v_result jsonb;
  v_id uuid;
  v_band_id uuid;
  v_song_id uuid;
  v_setlist_id uuid;
  v_position double precision;
  v_at timestamptz;
  v_count integer;
  v_current jsonb;
  v_set jsonb;
  v_base jsonb;
  v_apply jsonb := '{}'::jsonb;
  v_conflicts jsonb := '[]'::jsonb;
  v_pair record;
  v_columns text;
begin
  if v_user is null then return jsonb_build_object('status', 'auth', 'message', 'Sign in is required.'); end if;
  if p_operation is null or jsonb_typeof(p_operation) <> 'object'
     or (p_operation->>'qid') is distinct from p_operation_id::text then
    return jsonb_build_object('status', 'permanent', 'message', 'The queued operation ID is invalid.');
  end if;

  -- Serialize the same user's retries for one operation ID before checking its receipt.
  perform pg_advisory_xact_lock(hashtextextended(v_user::text || ':' || p_operation_id::text, 0));
  select * into v_existing from public.offline_operation_receipts
    where user_id = v_user and operation_id = p_operation_id;
  if found then
    if v_existing.operation is distinct from p_operation then
      return jsonb_build_object('status', 'permanent', 'message', 'This operation ID was already used for different data.');
    end if;
    if v_existing.result->>'status' = 'applied' then
      return jsonb_build_object('status', 'duplicate', 'replayed', true);
    end if;
    return v_existing.result || jsonb_build_object('replayed', true);
  end if;

  perform set_config('app.offline_operation_rpc', 'on', true);
  v_type := p_operation->>'t';
  v_row := p_operation->'row';
  v_at := coalesce(nullif(p_operation->>'at', '')::timestamptz, now());

  if v_type = 'songNew' then
    v_id := (v_row->>'id')::uuid; v_band_id := (v_row->>'band_id')::uuid;
    insert into public.songs (id, band_id, title, artist, version_label, bpm, musical_key, time_signature, chords, root_notes, chords_url, bassline_url, notes, song_structure, lyrics_url, youtube_url, spotify_url, moises_url, catalog_ref, created_by)
      values (v_id, v_band_id, v_row->>'title', coalesce(v_row->>'artist', ''), coalesce(v_row->>'version_label', ''), nullif(v_row->>'bpm', '')::integer,
        v_row->>'musical_key', coalesce(v_row->>'time_signature', '4/4'), coalesce(v_row->>'chords', ''), coalesce(v_row->>'root_notes', ''),
        v_row->>'chords_url', v_row->>'bassline_url', coalesce(v_row->>'notes', ''), coalesce(v_row->>'song_structure', ''), v_row->>'lyrics_url', v_row->>'youtube_url',
        v_row->>'spotify_url', v_row->>'moises_url', v_row->>'catalog_ref', v_user)
      on conflict (id) do nothing;
    get diagnostics v_count = row_count;
    if v_count = 0 then
      select to_jsonb(s) into v_current from public.songs s where s.id = v_id;
      if v_current is null or not (v_current @> (v_row || jsonb_build_object('created_by', v_user))) then
        return jsonb_build_object('status', 'permanent', 'message', 'A song with this ID already exists with different data, or is not accessible.');
      end if;
    end if;

  elsif v_type = 'slAdd' then
    v_id := (v_row->>'id')::uuid; v_band_id := (v_row->>'band_id')::uuid;
    v_setlist_id := (v_row->>'setlist_id')::uuid; v_song_id := (v_row->>'song_id')::uuid;
    v_position := (v_row->>'position')::double precision;
    insert into public.setlist_songs (id, band_id, setlist_id, song_id, position, bpm_override, key_override, notes_override)
      values (v_id, v_band_id, v_setlist_id, v_song_id, v_position,
        nullif(v_row->>'bpm_override', '')::integer, v_row->>'key_override', v_row->>'notes_override')
      on conflict (id) do nothing;
    get diagnostics v_count = row_count;
    if v_count = 0 then
      select to_jsonb(s) into v_current from public.setlist_songs s where s.id = v_id;
      if v_current is null or not (v_current @> jsonb_build_object(
        'band_id', v_band_id, 'setlist_id', v_setlist_id, 'song_id', v_song_id, 'position', v_position,
        'bpm_override', nullif(v_row->>'bpm_override', '')::integer,
        'key_override', v_row->>'key_override', 'notes_override', v_row->>'notes_override'
      )) then
        return jsonb_build_object('status', 'permanent', 'message', 'A setlist entry with this ID already exists with different data, or is not accessible.');
      end if;
    end if;

  elsif v_type = 'linkAdd' then
    v_id := (v_row->>'id')::uuid; v_song_id := (v_row->>'song_id')::uuid;
    select s.band_id into v_band_id from public.songs s where s.id = v_song_id;
    if v_band_id is null then return jsonb_build_object('status', 'permanent', 'message', 'The song for this link no longer exists or is not accessible.'); end if;
    if v_row ? 'band_id' and (v_row->>'band_id')::uuid <> v_band_id then return jsonb_build_object('status', 'permanent', 'message', 'The link band does not match its song.'); end if;
    insert into public.song_links (id, band_id, song_id, kind, label, url, added_by)
      values (v_id, v_band_id, v_song_id, coalesce(v_row->>'kind', 'other'), coalesce(v_row->>'label', ''), v_row->>'url', v_user)
      on conflict (id) do nothing;
    get diagnostics v_count = row_count;
    if v_count = 0 then
      select to_jsonb(l) into v_current from public.song_links l where l.id = v_id;
      if v_current is null or not (v_current @> jsonb_build_object('band_id', v_band_id, 'song_id', v_song_id, 'kind', coalesce(v_row->>'kind', 'other'), 'label', coalesce(v_row->>'label', ''), 'url', v_row->>'url', 'added_by', v_user)) then
        return jsonb_build_object('status', 'permanent', 'message', 'A link with this ID already exists with different data, or is not accessible.');
      end if;
    end if;

  elsif v_type = 'slPos' then
    update public.setlist_songs set position = (p_operation->>'position')::double precision where id = (p_operation->>'id')::uuid;
    get diagnostics v_count = row_count;
    if v_count = 0 then return jsonb_build_object('status', 'permanent', 'message', 'That setlist entry no longer exists, or you no longer have permission to change it.'); end if;

  elsif v_type = 'slRemove' then
    update public.setlist_songs set deleted_at = coalesce(deleted_at, v_at) where id = (p_operation->>'id')::uuid;
    get diagnostics v_count = row_count;
    if v_count = 0 then return jsonb_build_object('status', 'permanent', 'message', 'That setlist entry no longer exists, or you no longer have permission to change it.'); end if;

  elsif v_type = 'songDel' then
    update public.songs set deleted_at = coalesce(deleted_at, v_at) where id = (p_operation->>'sid')::uuid;
    get diagnostics v_count = row_count;
    if v_count = 0 then return jsonb_build_object('status', 'permanent', 'message', 'This song no longer exists, or you no longer have permission to change it.'); end if;

  elsif v_type = 'linkDel' then
    update public.song_links set deleted_at = coalesce(deleted_at, v_at) where id = (p_operation->>'id')::uuid;
    get diagnostics v_count = row_count;
    if v_count = 0 then return jsonb_build_object('status', 'permanent', 'message', 'That link no longer exists, or you no longer have permission to change it.'); end if;

  elsif v_type = 'song' then
    v_song_id := (p_operation->>'sid')::uuid; v_set := p_operation->'set'; v_base := p_operation->'base';
    if jsonb_typeof(v_set) is distinct from 'object' or jsonb_typeof(v_base) is distinct from 'object' then
      return jsonb_build_object('status', 'permanent', 'message', 'The song edit is missing its changed fields or base values.');
    end if;
    if v_set = '{}'::jsonb then return jsonb_build_object('status', 'permanent', 'message', 'The song edit has no changed fields.'); end if;
    select to_jsonb(s) into v_current from public.songs s where s.id = v_song_id and s.deleted_at is null for update;
    if v_current is null then return jsonb_build_object('status', 'permanent', 'message', 'This song was deleted by someone else, or is not accessible.'); end if;
    for v_pair in select key, value from jsonb_each(v_set) loop
      if v_pair.key not in ('title','artist','version_label','bpm','musical_key','time_signature','chords','root_notes','chords_url','bassline_url','notes','song_structure','lyrics_url','youtube_url','spotify_url','moises_url','catalog_ref') then
        return jsonb_build_object('status', 'permanent', 'message', 'The song edit includes an unsupported field.');
      end if;
      if coalesce(v_current->>(v_pair.key), '') = coalesce(v_pair.value #>> '{}', '') then continue; end if;
      if coalesce(v_current->>(v_pair.key), '') = coalesce(v_base->(v_pair.key) #>> '{}', '') then
        v_apply := v_apply || jsonb_build_object(v_pair.key, v_pair.value);
      else
        v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object('field', v_pair.key, 'mine', v_pair.value, 'theirs', v_current->(v_pair.key)));
      end if;
    end loop;
    if v_apply <> '{}'::jsonb then
      select string_agg(format('%1$I = r.%1$I', fields.key), ', ') into v_columns from jsonb_object_keys(v_apply) as fields(key);
      execute format('update public.songs s set %s, change_note = $2 from jsonb_populate_record(null::public.songs, $1) r where s.id = $3', v_columns)
        using v_apply, coalesce(nullif(p_operation->>'note', ''), case when coalesce((p_operation->>'offline')::boolean, false) then 'Edited offline' end), v_song_id;
    end if;
    if jsonb_array_length(v_conflicts) > 0 then
      v_result := jsonb_build_object('status', 'conflict', 'conflicts', v_conflicts);
    end if;
  elsif v_type = 'note' then
    v_song_id := (p_operation->>'sid')::uuid;
    if nullif(trim(coalesce(p_operation->>'note', '')), '') is null then
      return jsonb_build_object('status', 'permanent', 'message', 'A reason is required.');
    end if;
    perform public.add_song_note(v_song_id, p_operation->>'note');
  else
    return jsonb_build_object('status', 'permanent', 'message', 'Unsupported offline operation type.');
  end if;

  if v_result is null then v_result := jsonb_build_object('status', 'applied'); end if;
  insert into public.offline_operation_receipts (user_id, operation_id, operation, result)
    values (v_user, p_operation_id, p_operation, v_result);
  return v_result;
end;
$$;

revoke all on function public.apply_offline_operation(uuid, jsonb) from public, anon;
grant execute on function public.apply_offline_operation(uuid, jsonb) to authenticated;

comment on table public.offline_operation_receipts is
  'Per-user idempotency receipts for offline queue RPC operations; retained so retries after lost responses do not repeat changes.';
comment on function public.apply_offline_operation(uuid, jsonb) is
  'Applies one queued operation under caller RLS and stores its per-user idempotency receipt in the same transaction.';
