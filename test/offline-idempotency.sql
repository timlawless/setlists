-- Phase 2A.3 integration check for schema_v14_offline_operation_idempotency.sql.
-- Run only on a non-production Supabase project after applying schema v14.
-- Run the whole script in one SQL-editor session. The transaction is rolled back.
-- Requires one band member and a second authenticated user who is not in that band.

begin;

select set_config('test.offline_member', (select user_id::text from public.band_members order by joined_at limit 1), true);
select set_config('test.offline_band', (
  select band_id::text from public.band_members
  where user_id::text = current_setting('test.offline_member', true)
  order by joined_at limit 1
), true);
select set_config('test.offline_outsider', (
  select u.id::text from auth.users u
  where u.id::text <> current_setting('test.offline_member', true)
    and not exists (
      select 1 from public.band_members bm
      where bm.user_id = u.id and bm.band_id::text = current_setting('test.offline_band', true)
    )
  order by u.created_at limit 1
), true);

do $$
begin
  if current_setting('test.offline_member', true) is null or current_setting('test.offline_band', true) is null then
    raise exception 'Create a test band with at least one member before running this script';
  end if;
  if current_setting('test.offline_outsider', true) is null then
    raise exception 'A second auth user outside the selected band is required for the RLS check';
  end if;
  perform set_config('request.jwt.claim.sub', current_setting('test.offline_member', true), true);
end $$;

set local role authenticated;

do $$
declare
  v_user uuid := auth.uid();
  v_band uuid := current_setting('test.offline_band', true)::uuid;
  v_operation_id uuid := gen_random_uuid();
  v_song_id uuid := gen_random_uuid();
  v_setlist_id uuid := gen_random_uuid();
  v_entry_id uuid := gen_random_uuid();
  v_link_id uuid := gen_random_uuid();
  v_operation jsonb;
  v_other_operation jsonb;
  v_first jsonb;
  v_second jsonb;
  v_changed jsonb;
  v_count integer;
  v_outsider_result jsonb;
begin
  v_operation := jsonb_build_object(
    'qid', v_operation_id, 't', 'songNew', 'offline', true, 'at', now(),
    'row', jsonb_build_object('id', v_song_id, 'band_id', v_band, 'title', 'Idempotency test', 'artist', 'test', 'bpm', 120, 'musical_key', 'C', 'spotify_url', null, 'moises_url', null, 'catalog_ref', 'test-catalog-ref', 'created_by', v_user)
  );
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then
    raise exception 'Expected applied then duplicate results, got % and %', v_first, v_second;
  end if;
  select count(*) into v_count from public.songs where id = v_song_id and catalog_ref = 'test-catalog-ref';
  if v_count <> 1 then raise exception 'Retry inserted % song rows instead of one', v_count; end if;
  select count(*) into v_count from public.change_log where row_id = v_song_id and table_name = 'songs';
  if v_count <> 1 then raise exception 'Retry produced % song history rows instead of one', v_count; end if;
  select count(*) into v_count from public.offline_operation_receipts where user_id = v_user and operation_id = v_operation_id;
  if v_count <> 1 then raise exception 'Retry stored % idempotency receipts instead of one', v_count; end if;

  v_changed := jsonb_set(v_operation, '{row,title}', to_jsonb('Different title'::text));
  if public.apply_offline_operation(v_operation_id, v_changed)->>'status' <> 'permanent' then
    raise exception 'Reusing an operation ID with changed data was not rejected';
  end if;

  insert into public.setlists (id, band_id, name, created_by) values (v_setlist_id, v_band, 'Idempotency test', v_user);
  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'slAdd', 'at', now(), 'row', jsonb_build_object('id', v_entry_id, 'band_id', v_band, 'setlist_id', v_setlist_id, 'song_id', v_song_id, 'position', 1));
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Setlist-add retry failed: % / %', v_first, v_second; end if;

  v_changed := jsonb_set(jsonb_set(v_operation, '{qid}', to_jsonb(gen_random_uuid())), '{row,bpm_override}', to_jsonb(120));
  if public.apply_offline_operation((v_changed->>'qid')::uuid, v_changed)->>'status' <> 'permanent' then raise exception 'Setlist-add duplicate comparison ignored bpm_override'; end if;
  v_changed := jsonb_set(jsonb_set(v_operation, '{qid}', to_jsonb(gen_random_uuid())), '{row,key_override}', to_jsonb('G'::text));
  if public.apply_offline_operation((v_changed->>'qid')::uuid, v_changed)->>'status' <> 'permanent' then raise exception 'Setlist-add duplicate comparison ignored key_override'; end if;
  v_changed := jsonb_set(jsonb_set(v_operation, '{qid}', to_jsonb(gen_random_uuid())), '{row,notes_override}', to_jsonb('Test notes'::text));
  if public.apply_offline_operation((v_changed->>'qid')::uuid, v_changed)->>'status' <> 'permanent' then raise exception 'Setlist-add duplicate comparison ignored notes_override'; end if;

  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'slPos', 'id', v_entry_id, 'position', 2, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Setlist-position retry failed: % / %', v_first, v_second; end if;

  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'song', 'sid', v_song_id, 'base', jsonb_build_object('bpm', 120, 'spotify_url', null, 'moises_url', null), 'set', jsonb_build_object('bpm', 130, 'spotify_url', 'https://open.spotify.com/track/test', 'moises_url', 'https://moises.ai/test'), 'note', 'idempotency test edit', 'offline', true, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Song-edit retry failed: % / %', v_first, v_second; end if;
  select count(*) into v_count from public.songs where id = v_song_id and spotify_url = 'https://open.spotify.com/track/test' and moises_url = 'https://moises.ai/test' and change_note = 'idempotency test edit';
  if v_count <> 1 then raise exception 'Song edit did not persist the Spotify, Moises, and change-note fields'; end if;

  update public.songs set chords = 'C' where id = v_song_id;
  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'song', 'sid', v_song_id, 'base', jsonb_build_object('bpm', 130, 'chords', ''), 'set', jsonb_build_object('bpm', 140, 'chords', 'G'), 'offline', true, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'conflict' or v_second->>'status' <> 'conflict' or jsonb_array_length(v_first->'conflicts') <> 1 then raise exception 'Song conflict replay changed behavior: % / %', v_first, v_second; end if;
  select count(*) into v_count from public.songs where id = v_song_id and bpm = 140 and chords = 'C';
  if v_count <> 1 then raise exception 'Song conflict resolution did not preserve its non-conflicting field'; end if;

  v_operation_id := gen_random_uuid(); v_link_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'linkAdd', 'row', jsonb_build_object('id', v_link_id, 'band_id', v_band, 'song_id', v_song_id, 'kind', 'other', 'label', 'test', 'url', 'https://example.test', 'added_by', v_user));
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Link-add retry failed: % / %', v_first, v_second; end if;

  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'linkDel', 'id', v_link_id, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Link-delete retry failed: % / %', v_first, v_second; end if;

  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'slRemove', 'id', v_entry_id, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Setlist-remove retry failed: % / %', v_first, v_second; end if;

  v_operation_id := gen_random_uuid();
  v_operation := jsonb_build_object('qid', v_operation_id, 't', 'songDel', 'sid', v_song_id, 'at', now());
  v_first := public.apply_offline_operation(v_operation_id, v_operation);
  v_second := public.apply_offline_operation(v_operation_id, v_operation);
  if v_first->>'status' <> 'applied' or v_second->>'status' <> 'duplicate' then raise exception 'Song-delete retry failed: % / %', v_first, v_second; end if;

  v_other_operation := jsonb_build_object('qid', (v_operation->>'qid')::uuid, 't', 'songNew', 'at', now(), 'row', jsonb_build_object('id', v_song_id, 'band_id', v_band, 'title', 'Idempotency test', 'artist', 'test', 'bpm', 120, 'musical_key', 'C'));
  perform set_config('request.jwt.claim.sub', current_setting('test.offline_outsider', true), true);
  begin
    v_outsider_result := public.apply_offline_operation((v_other_operation->>'qid')::uuid, v_other_operation);
  exception when insufficient_privilege then
    v_outsider_result := jsonb_build_object('status', 'denied');
  end;
  if v_outsider_result->>'status' = 'duplicate' then
    raise exception 'Another user received this account’s idempotency receipt';
  end if;
  select count(*) into v_count from public.songs where id = v_song_id;
  if v_count <> 0 then raise exception 'An outsider could read the member song'; end if;
end $$;

rollback;
