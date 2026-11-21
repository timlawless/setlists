-- Setlist app, SQL v13: allow the new "Backing singer" instrument role (stored as the value 'backing').
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: instrument roles are stored in band_members.roles. If that column has a rule that limits which role names are
-- allowed (a check rule, or a list type), this adds 'backing' to what is allowed. If there is no such rule, it changes nothing.
-- It never touches who can see or change anything: the access rules are not affected.
-- The Notice lines in the results say which case applied.

do $$
declare
  el oid;
  c record;
  had_check boolean := false;
begin
  select t.typelem into el
    from pg_attribute a join pg_type t on t.oid = a.atttypid
   where a.attrelid = 'public.band_members'::regclass and a.attname = 'roles' and not a.attisdropped;
  if el is null or el = 0 then
    raise notice 'band_members.roles was not found as a list column: nothing to change.';
    return;
  end if;

  if exists (select 1 from pg_type where oid = el and typtype = 'e') then
    execute format('alter type %s add value if not exists %L', el::regtype, 'backing');
    raise notice 'roles uses a list type: added the value backing.';
    return;
  end if;

  for c in
    select conname from pg_constraint
     where conrelid = 'public.band_members'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%roles%'
  loop
    had_check := true;
    execute format('alter table public.band_members drop constraint %I', c.conname);
  end loop;

  if had_check then
    alter table public.band_members add constraint band_members_roles_allowed
      check (roles::text[] <@ array['singer', 'guitarist', 'bassist', 'drummer', 'keyboards', 'backing']::text[]) not valid;
    raise notice 'roles had a rule limiting the names: it now also allows backing.';
  else
    raise notice 'roles has no rule limiting the names: nothing to change.';
  end if;
end $$;
