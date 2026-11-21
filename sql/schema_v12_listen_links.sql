-- Setlist app, SQL v12: two new link boxes on a song, for Spotify and for the band's own Moises version.
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: adds two optional text columns to public.songs, spotify_url and moises_url. They behave like the existing
-- lyrics_url and youtube_url columns: the same row-level security applies (members of the band read, editors and above change),
-- and the existing history trigger records changes to them without any change to it. Nothing else is touched.

alter table public.songs add column if not exists spotify_url text;
alter table public.songs add column if not exists moises_url  text;

-- Check (optional): both columns should be listed.
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'songs' and column_name in ('spotify_url', 'moises_url');
