-- =====================================================================
-- Setlist app: Supabase schema v1
-- Run in the Supabase SQL editor (or as a migration). Safe on an empty project.
-- Design notes:
--   * Every row has a uuid id (clients can create rows offline) plus updated_at
--     and deleted_at (soft delete) so offline sync can ask "what changed since X?".
--   * Members-only access: RLS checks band_members. All band members can edit.
--   * Bands are created and joined through RPC functions (create_band, join_band).
--   * change_log records every insert/update/delete on band data (version history).
--   * Colours: profiles.theme (personal default) and band_members.theme (per band).
-- =====================================================================

-- ---------- 1. Tables ------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default '',
  theme_mode    text not null default 'system' check (theme_mode in ('light','dark','system')),
  theme         jsonb not null default '{}'::jsonb,   -- e.g. {"primary":"#2563eb","accent":"#f59e0b"}
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.bands (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(trim(name)) between 1 and 80),
  created_by  uuid not null references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.band_members (
  band_id    uuid not null references public.bands(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('owner','member')),
  theme      jsonb not null default '{}'::jsonb,       -- this person's colours for this band
  joined_at  timestamptz not null default now(),
  primary key (band_id, user_id)
);
create index band_members_user_idx on public.band_members(user_id);

create table public.band_invites (
  id          uuid primary key default gen_random_uuid(),
  band_id     uuid not null references public.bands(id) on delete cascade,
  code        text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_by  uuid not null references public.profiles(id),
  expires_at  timestamptz not null default now() + interval '7 days',
  created_at  timestamptz not null default now()
);

create table public.songs (
  id              uuid primary key default gen_random_uuid(),
  band_id         uuid not null references public.bands(id) on delete cascade,
  title           text not null,
  artist          text not null default '',
  version_label   text not null default '',            -- which artist's version, e.g. "Aerosmith & Run-DMC"
  bpm             int check (bpm between 20 and 400),
  musical_key     text,                                -- original key by default, band can edit
  time_signature  text not null default '4/4',
  chords          text not null default '',
  notes           text not null default '',
  lyrics_url      text,
  youtube_url     text,
  catalog_ref     text,                                -- external id for BPM/key lookup (later)
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  unique (id, band_id)
);
create index songs_band_updated_idx on public.songs(band_id, updated_at);

-- Extra links on a song: sheet music, tabs, lyrics, videos added by members
create table public.song_links (
  id          uuid primary key default gen_random_uuid(),
  band_id     uuid not null,
  song_id     uuid not null,
  kind        text not null default 'other' check (kind in ('sheet_music','tab','lyrics','video','other')),
  url         text not null,
  label       text not null default '',
  added_by    uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  foreign key (song_id, band_id) references public.songs(id, band_id) on delete cascade
);
create index song_links_song_idx on public.song_links(song_id);
create index song_links_band_updated_idx on public.song_links(band_id, updated_at);

create table public.setlists (
  id          uuid primary key default gen_random_uuid(),
  band_id     uuid not null references public.bands(id) on delete cascade,
  name        text not null,
  gig_date    date,
  venue       text not null default '',
  notes       text not null default '',
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  unique (id, band_id)
);
create index setlists_band_updated_idx on public.setlists(band_id, updated_at);

-- Songs in a setlist. position is a float so reordering = pick a value between neighbours
-- (works offline without rewriting every row). Overrides let one gig change key/tempo.
create table public.setlist_songs (
  id              uuid primary key default gen_random_uuid(),
  band_id         uuid not null,
  setlist_id      uuid not null,
  song_id         uuid not null,
  position        double precision not null,
  bpm_override    int check (bpm_override between 20 and 400),
  key_override    text,
  notes_override  text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  foreign key (setlist_id, band_id) references public.setlists(id, band_id) on delete cascade,
  foreign key (song_id, band_id)    references public.songs(id, band_id)    on delete cascade
);
create index setlist_songs_order_idx on public.setlist_songs(setlist_id, position);
create index setlist_songs_band_updated_idx on public.setlist_songs(band_id, updated_at);

-- Version history of every change to band data
create table public.change_log (
  id          bigint generated always as identity primary key,
  band_id     uuid not null,
  table_name  text not null,
  row_id      uuid not null,
  op          text not null check (op in ('INSERT','UPDATE','DELETE')),
  old_data    jsonb,
  new_data    jsonb,
  changed_by  uuid default auth.uid(),
  changed_at  timestamptz not null default now()
);
create index change_log_band_time_idx on public.change_log(band_id, changed_at desc);
create index change_log_row_idx on public.change_log(table_name, row_id, changed_at desc);

-- ---------- 2. Helper functions --------------------------------------

create function public.is_band_member(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid());
$$;

create function public.is_band_owner(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid() and role = 'owner');
$$;

create function public.shares_band_with(u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.band_members mine
    join public.band_members theirs on theirs.band_id = mine.band_id
    where mine.user_id = auth.uid() and theirs.user_id = u
  );
$$;

-- ---------- 3. Triggers ----------------------------------------------

create function public.touch_row() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger touch_profiles       before update on public.profiles       for each row execute function public.touch_row();
create trigger touch_bands          before update on public.bands          for each row execute function public.touch_row();
create trigger touch_songs          before update on public.songs          for each row execute function public.touch_row();
create trigger touch_song_links     before update on public.song_links     for each row execute function public.touch_row();
create trigger touch_setlists       before update on public.setlists       for each row execute function public.touch_row();
create trigger touch_setlist_songs  before update on public.setlist_songs  for each row execute function public.touch_row();

create function public.log_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.change_log(band_id, table_name, row_id, op, new_data)
    values (new.band_id, tg_table_name, new.id, 'INSERT', to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    if to_jsonb(old) - 'updated_at' = to_jsonb(new) - 'updated_at' then
      return new;  -- nothing really changed
    end if;
    insert into public.change_log(band_id, table_name, row_id, op, old_data, new_data)
    values (new.band_id, tg_table_name, new.id, 'UPDATE', to_jsonb(old), to_jsonb(new));
    return new;
  else
    insert into public.change_log(band_id, table_name, row_id, op, old_data)
    values (old.band_id, tg_table_name, old.id, 'DELETE', to_jsonb(old));
    return old;
  end if;
end $$;

create trigger log_songs          after insert or update or delete on public.songs          for each row execute function public.log_change();
create trigger log_song_links     after insert or update or delete on public.song_links     for each row execute function public.log_change();
create trigger log_setlists       after insert or update or delete on public.setlists       for each row execute function public.log_change();
create trigger log_setlist_songs  after insert or update or delete on public.setlist_songs  for each row execute function public.log_change();

-- Create a profile automatically when someone signs up
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 4. RPC functions (create and join bands) -----------------

create function public.create_band(p_name text) returns public.bands
language plpgsql security definer set search_path = public as $$
declare b public.bands;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.bands(name, created_by) values (trim(p_name), auth.uid()) returning * into b;
  insert into public.band_members(band_id, user_id, role) values (b.id, auth.uid(), 'owner');
  return b;
end $$;

create function public.join_band(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare inv public.band_invites;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into inv from public.band_invites
   where code = upper(trim(p_code)) and expires_at > now();
  if not found then raise exception 'invalid or expired invite code'; end if;
  insert into public.band_members(band_id, user_id) values (inv.band_id, auth.uid())
  on conflict do nothing;
  return inv.band_id;
end $$;

revoke all on function public.create_band(text), public.join_band(text) from public, anon;
grant execute on function public.create_band(text), public.join_band(text) to authenticated;
grant execute on function public.is_band_member(uuid), public.is_band_owner(uuid), public.shares_band_with(uuid) to authenticated;

-- ---------- 5. Row level security ------------------------------------

alter table public.profiles       enable row level security;
alter table public.bands          enable row level security;
alter table public.band_members   enable row level security;
alter table public.band_invites   enable row level security;
alter table public.songs          enable row level security;
alter table public.song_links     enable row level security;
alter table public.setlists       enable row level security;
alter table public.setlist_songs  enable row level security;
alter table public.change_log     enable row level security;

-- profiles: see yourself and people you share a band with; edit only yourself
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_band_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- bands: members can see; owners can rename or delete (creation is via create_band)
create policy bands_select on public.bands for select to authenticated
  using (public.is_band_member(id));
create policy bands_update on public.bands for update to authenticated
  using (public.is_band_owner(id)) with check (public.is_band_owner(id));
create policy bands_delete on public.bands for delete to authenticated
  using (public.is_band_owner(id));

-- band_members: members see the roster; you can change your own colours or leave;
-- owners can remove people. Joining happens via join_band only.
create policy band_members_select on public.band_members for select to authenticated
  using (public.is_band_member(band_id));
create policy band_members_update_own on public.band_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy band_members_delete on public.band_members for delete to authenticated
  using (user_id = auth.uid() or public.is_band_owner(band_id));
-- only the theme column can be edited directly (stops people promoting themselves to owner)
revoke update on public.band_members from authenticated;
grant update (theme) on public.band_members to authenticated;

-- invites: any member can list, create and delete invites for their band
create policy band_invites_select on public.band_invites for select to authenticated
  using (public.is_band_member(band_id));
create policy band_invites_insert on public.band_invites for insert to authenticated
  with check (public.is_band_member(band_id) and created_by = auth.uid());
create policy band_invites_delete on public.band_invites for delete to authenticated
  using (public.is_band_member(band_id));

-- band data: every member can read, add and edit; only owners can hard-delete
-- (members "delete" by setting deleted_at, which keeps offline sync simple)
do $$
declare t text;
begin
  foreach t in array array['songs','song_links','setlists','setlist_songs'] loop
    execute format('create policy %I on public.%I for select to authenticated using (public.is_band_member(band_id))', t || '_select', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_band_member(band_id))', t || '_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_band_member(band_id)) with check (public.is_band_member(band_id))', t || '_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_band_owner(band_id))', t || '_delete', t);
  end loop;
end $$;

-- history: members can read it; only the triggers write to it
create policy change_log_select on public.change_log for select to authenticated
  using (public.is_band_member(band_id));

-- ---------- 6. Realtime (live sync between band members) -------------

alter publication supabase_realtime add table
  public.songs, public.song_links, public.setlists, public.setlist_songs;
