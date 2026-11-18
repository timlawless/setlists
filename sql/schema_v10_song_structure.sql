-- Setlist app, SQL v10: an optional free-text "Song structure" on each song, for example: V C V C M8 V C Outro
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: adds one column, songs.song_structure (text, never null, empty by default).
-- Existing songs get an empty value and are otherwise untouched. Adding the column does not update any rows,
-- so it adds nothing to the change history.
-- There are no policy, trigger, grant or index changes. The app reads songs with "select *", the history trigger
-- records the whole row, and the existing row-level security applies to the new column like the others.
-- (That last point is expected, not confirmed: the v3 to v8 files are not in the repository. See the optional checks.)
--
-- Optional check BEFORE running (read only): this should return no rows.
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'songs' and column_name = 'song_structure';
--
-- Optional check AFTER running (read only): this should return one row: text, NO, ''::text
--   select column_name, data_type, is_nullable, column_default from information_schema.columns
--    where table_schema = 'public' and table_name = 'songs' and column_name = 'song_structure';

alter table public.songs add column if not exists song_structure text not null default '';
