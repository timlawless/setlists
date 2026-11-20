-- Setlist app, SQL v11: remember each person's guitar or bass view of a song's chord/progression box.
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: adds one small table, song_views, with at most one row per person per song ('guitar' or 'bass').
-- A person can read and change only their own rows, and only for bands they belong to. Nothing else is touched:
-- songs, setlists and the change history are not affected, and the bass line itself is stored in the existing
-- songs.root_notes column (added in v3).
-- Until this file is run the app still works: the choice is kept on the device and is sent here once the table exists.

create table if not exists public.song_views (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  song_id     uuid not null,
  band_id     uuid not null references public.bands(id) on delete cascade,
  view        text not null check (view in ('guitar', 'bass')),
  updated_at  timestamptz not null default now(),
  primary key (user_id, song_id),
  foreign key (song_id, band_id) references public.songs(id, band_id) on delete cascade
);
create index if not exists song_views_band_user_idx on public.song_views(band_id, user_id);

drop trigger if exists touch_song_views on public.song_views;
create trigger touch_song_views before update on public.song_views for each row execute function public.touch_row();

alter table public.song_views enable row level security;

drop policy if exists song_views_select on public.song_views;
create policy song_views_select on public.song_views for select to authenticated
  using (user_id = auth.uid() and public.is_band_member(band_id));

drop policy if exists song_views_insert on public.song_views;
create policy song_views_insert on public.song_views for insert to authenticated
  with check (user_id = auth.uid() and public.is_band_member(band_id));

drop policy if exists song_views_update on public.song_views;
create policy song_views_update on public.song_views for update to authenticated
  using (user_id = auth.uid() and public.is_band_member(band_id))
  with check (user_id = auth.uid() and public.is_band_member(band_id));

drop policy if exists song_views_delete on public.song_views;
create policy song_views_delete on public.song_views for delete to authenticated
  using (user_id = auth.uid());

revoke all on public.song_views from anon, public;
grant select, insert, update, delete on public.song_views to authenticated;

-- Check (optional): should list the four policies and return 0 rows when you have not chosen a view yet.
--   select policyname from pg_policies where tablename = 'song_views';
--   select count(*) from public.song_views;
