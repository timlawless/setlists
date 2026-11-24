-- Setlists SQL v16: create a harmless endpoint for the Supabase Free-project keep-alive check.
-- Run once in the Supabase SQL Editor. Safe to run more than once.
--
-- The GitHub Actions workflow reads the single fixed row using the public anon key.
-- No band, song, account or other application data is exposed or modified.

create table if not exists public.keepalive_check (
  id integer primary key check (id = 1)
);

insert into public.keepalive_check (id)
values (1)
on conflict (id) do nothing;

alter table public.keepalive_check enable row level security;

revoke all on table public.keepalive_check from public, anon, authenticated;
grant select on table public.keepalive_check to anon;

drop policy if exists keepalive_check_anon_select on public.keepalive_check;
create policy keepalive_check_anon_select
  on public.keepalive_check
  for select
  to anon
  using (true);

comment on table public.keepalive_check is
  'Contains one harmless row read by the scheduled GitHub Actions Supabase keep-alive check.';
