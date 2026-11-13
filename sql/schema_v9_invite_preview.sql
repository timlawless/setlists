-- Setlist app, SQL v9: let the invitation page show the band name before the person has an account.
-- Run this in the Supabase SQL Editor BEFORE uploading the new index.html. Safe to run more than once.
--
-- What it does: adds one function, invite_preview(code). Given a valid, unexpired invite code it returns the band's name
-- and the access level the invitation gives. It returns nothing for a wrong or expired code. It exposes no other data:
-- the band_invites and bands tables themselves stay private. Joining still happens only through join_band, after sign-in.

create or replace function public.invite_preview(p_code text)
returns table (band_name text, role text)
language sql stable security definer set search_path = public as $$
  select b.name::text, i.role::text
    from public.band_invites i
    join public.bands b on b.id = i.band_id
   where i.code = upper(trim(p_code))
     and i.expires_at > now()
   limit 1;
$$;

revoke all on function public.invite_preview(text) from public;
grant execute on function public.invite_preview(text) to anon, authenticated;

-- Check (optional): replace CODE with a real invite code from the app; you should get one row with the band name and level.
--   select * from public.invite_preview('CODE');
