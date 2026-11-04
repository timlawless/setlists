-- Schema v2: lets people record a reason with a change, and shows it in the history.
-- Run once in the Supabase SQL editor. Safe to run again.

-- 1. A place to hold the reason alongside a song edit
alter table public.songs add column if not exists change_note text;

-- 2. The history table gets a reason column
alter table public.change_log add column if not exists reason text;

-- 3. Update the history trigger: copy the reason into the log, and do not
--    log an update where only the reason or the timestamp differs.
create or replace function public.log_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.change_log(band_id, table_name, row_id, op, new_data, reason)
    values (new.band_id, tg_table_name, new.id, 'INSERT', to_jsonb(new), to_jsonb(new)->>'change_note');
    return new;
  elsif tg_op = 'UPDATE' then
    if (to_jsonb(old) - 'updated_at' - 'change_note') = (to_jsonb(new) - 'updated_at' - 'change_note') then
      return new;  -- nothing real changed
    end if;
    insert into public.change_log(band_id, table_name, row_id, op, old_data, new_data, reason)
    values (new.band_id, tg_table_name, new.id, 'UPDATE', to_jsonb(old), to_jsonb(new), to_jsonb(new)->>'change_note');
    return new;
  else
    insert into public.change_log(band_id, table_name, row_id, op, old_data)
    values (old.band_id, tg_table_name, old.id, 'DELETE', to_jsonb(old));
    return old;
  end if;
end $$;
