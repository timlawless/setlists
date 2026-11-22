-- Setlist app, SQL v15: add a reason to a song's History without changing the song.
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: adds one function, add_song_note(song, note). It records the note as its own new entry in the song's History
-- (the entry shows as "Note added" with the reason and who wrote it). Nothing in the song itself changes, and no earlier History
-- entry is changed: History is only ever added to. Only owners, admins and editors of the song's band can use it.
-- The existing History trigger is not touched.

create or replace function public.add_song_note(p_song uuid, p_note text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  s public.songs;
  n text := trim(coalesce(p_note, ''));
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if n = '' then raise exception 'a reason is needed'; end if;
  if char_length(n) > 500 then raise exception 'the reason is too long (500 characters at most)'; end if;
  select * into s from public.songs where id = p_song and deleted_at is null;
  if not found then raise exception 'song not found'; end if;
  if not exists (
    select 1 from public.band_members
     where band_id = s.band_id and user_id = auth.uid() and role::text in ('owner', 'admin', 'editor', 'member')
  ) then raise exception 'you do not have permission to add a reason to this song'; end if;
  insert into public.change_log(band_id, table_name, row_id, op, old_data, new_data, reason)
  values (s.band_id, 'songs', s.id, 'UPDATE', to_jsonb(s), to_jsonb(s), n);
end $$;

revoke all on function public.add_song_note(uuid, text) from public, anon;
grant execute on function public.add_song_note(uuid, text) to authenticated;

-- Check (optional), as a signed-in editor in the app: change nothing, type a reason, tap Save changes, then tap History.
