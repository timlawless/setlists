SET local check_function_bodies = off;

CREATE TABLE "public"."band_invites" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "band_id"    uuid                     NOT NULL,
  "code"       text                     NOT NULL DEFAULT upper(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 8)),
  "created_by" uuid                     NOT NULL,
  "expires_at" timestamp with time zone NOT NULL DEFAULT (now() + '7 days'::interval),
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "role"       text                     NOT NULL DEFAULT 'editor'::text,
  CONSTRAINT "band_invites_code_key" UNIQUE (code),
  CONSTRAINT "band_invites_pkey" PRIMARY KEY (id),
  CONSTRAINT "band_invites_role_check" CHECK ((role = ANY (ARRAY['editor'::text, 'viewer'::text])))
);

ALTER TABLE "public"."band_invites"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."band_members" (
  "band_id"         uuid                     NOT NULL,
  "user_id"         uuid                     NOT NULL,
  "role"            text                     NOT NULL DEFAULT 'editor'::text,
  "theme"           jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "joined_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "roles"           text[]                   NOT NULL DEFAULT '{}'::text[],
  "last_setlist_id" uuid,
  CONSTRAINT "band_members_pkey" PRIMARY KEY (band_id, user_id),
  CONSTRAINT "band_members_role_check" CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'editor'::text, 'viewer'::text]))),
  CONSTRAINT "band_members_roles_check" CHECK ((roles <@ ARRAY['singer'::text, 'guitarist'::text, 'bassist'::text, 'drummer'::text, 'keyboards'::text]))
);

ALTER TABLE "public"."band_members"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."bands" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"       text                     NOT NULL,
  "created_by" uuid                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "theme"      jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "logo"       text,
  "slug"       text,
  CONSTRAINT "bands_logo_check" CHECK (((logo IS NULL) OR ((length(logo) <= 250000) AND (logo ~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$'::text)))),
  CONSTRAINT "bands_name_check" CHECK (((char_length(TRIM(BOTH FROM name)) >= 1) AND (char_length(TRIM(BOTH FROM name)) <= 80))),
  CONSTRAINT "bands_pkey" PRIMARY KEY (id),
  CONSTRAINT "bands_slug_check"
    CHECK
    (((slug IS NULL) OR ((slug ~ '^[a-z0-9][a-z0-9-]{1,29}$'::text) AND (slug <> ALL (ARRAY['join'::text, 'invite'::text, 'admin'::text, 'login'::text, 'signin'::text,
    'signup'::text, 'new'::text, 'api'::text, 'app'::text, 'settings'::text, 'help'::text, 'null'::text])))))
);

ALTER TABLE "public"."bands"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."change_log" (
  "id"         bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  "band_id"    uuid                     NOT NULL,
  "table_name" text                     NOT NULL,
  "row_id"     uuid                     NOT NULL,
  "op"         text                     NOT NULL,
  "old_data"   jsonb,
  "new_data"   jsonb,
  "changed_at" timestamp with time zone NOT NULL DEFAULT now(),
  "reason"     text,
  CONSTRAINT "change_log_op_check" CHECK ((op = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text]))),
  CONSTRAINT "change_log_pkey" PRIMARY KEY (id),
  "changed_by" uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."change_log"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."profiles" (
  "id"           uuid                     NOT NULL,
  "display_name" text                     NOT NULL DEFAULT ''::text,
  "theme_mode"   text                     NOT NULL DEFAULT 'system'::text,
  "theme"        jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
  CONSTRAINT "profiles_theme_mode_check" CHECK ((theme_mode = ANY (ARRAY['light'::text, 'dark'::text, 'system'::text])))
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."setlist_songs" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "band_id"        uuid                     NOT NULL,
  "setlist_id"     uuid                     NOT NULL,
  "song_id"        uuid                     NOT NULL,
  "position"       double precision         NOT NULL,
  "bpm_override"   integer,
  "key_override"   text,
  "notes_override" text,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at"     timestamp with time zone,
  CONSTRAINT "setlist_songs_bpm_override_check" CHECK (((bpm_override >= 20) AND (bpm_override <= 400))),
  CONSTRAINT "setlist_songs_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."setlist_songs"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."setlists" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "band_id"    uuid                     NOT NULL,
  "name"       text                     NOT NULL,
  "gig_date"   date,
  "venue"      text                     NOT NULL DEFAULT ''::text,
  "notes"      text                     NOT NULL DEFAULT ''::text,
  "created_by" uuid,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at" timestamp with time zone,
  CONSTRAINT "setlists_id_band_id_key" UNIQUE (id, band_id),
  CONSTRAINT "setlists_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."setlists"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."song_links" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "band_id"    uuid                     NOT NULL,
  "song_id"    uuid                     NOT NULL,
  "kind"       text                     NOT NULL DEFAULT 'other'::text,
  "url"        text                     NOT NULL,
  "label"      text                     NOT NULL DEFAULT ''::text,
  "added_by"   uuid,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at" timestamp with time zone,
  CONSTRAINT "song_links_kind_check" CHECK ((kind = ANY (ARRAY['sheet_music'::text, 'tab'::text, 'lyrics'::text, 'video'::text, 'other'::text]))),
  CONSTRAINT "song_links_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."song_links"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."song_views" (
  "user_id"    uuid                     NOT NULL,
  "song_id"    uuid                     NOT NULL,
  "band_id"    uuid                     NOT NULL,
  "view"       text                     NOT NULL,
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "song_views_pkey" PRIMARY KEY (user_id, song_id),
  CONSTRAINT "song_views_view_check" CHECK ((view = ANY (ARRAY['guitar'::text, 'bass'::text])))
);

ALTER TABLE "public"."song_views"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."song_views" FROM "anon";

CREATE TABLE "public"."songs" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "band_id"        uuid                     NOT NULL,
  "title"          text                     NOT NULL,
  "artist"         text                     NOT NULL DEFAULT ''::text,
  "version_label"  text                     NOT NULL DEFAULT ''::text,
  "bpm"            integer,
  "musical_key"    text,
  "time_signature" text                     NOT NULL DEFAULT '4/4'::text,
  "chords"         text                     NOT NULL DEFAULT ''::text,
  "notes"          text                     NOT NULL DEFAULT ''::text,
  "lyrics_url"     text,
  "youtube_url"    text,
  "catalog_ref"    text,
  "created_by"     uuid,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at"     timestamp with time zone,
  "change_note"    text,
  "root_notes"     text                     NOT NULL DEFAULT ''::text,
  "song_structure" text                     NOT NULL DEFAULT ''::text,
  CONSTRAINT "songs_bpm_check" CHECK (((bpm >= 20) AND (bpm <= 400))),
  CONSTRAINT "songs_id_band_id_key" UNIQUE (id, band_id),
  CONSTRAINT "songs_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."songs"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_edit_band (
  b uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from public.band_members
                 where band_id = b and user_id = auth.uid() and role in ('owner','admin','editor'));
$function$;

CREATE OR REPLACE FUNCTION public.create_band (
  p_name text
)
  RETURNS public.bands
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare b public.bands;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.bands(name, created_by) values (trim(p_name), auth.uid()) returning * into b;
  insert into public.band_members(band_id, user_id, role) values (b.id, auth.uid(), 'owner');
  return b;
end $function$;

REVOKE ALL ON FUNCTION "public"."create_band"(text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.invite_preview (
  p_code text
)
  RETURNS TABLE (
    band_name text,
    role      text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select b.name::text, i.role::text
    from public.band_invites i
    join public.bands b on b.id = i.band_id
   where i.code = upper(trim(p_code))
     and i.expires_at > now()
   limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.is_band_admin (
  b uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from public.band_members
                 where band_id = b and user_id = auth.uid() and role in ('owner','admin'));
$function$;

CREATE OR REPLACE FUNCTION public.is_band_member (
  b uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid());
$function$;

CREATE OR REPLACE FUNCTION public.is_band_owner (
  b uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid() and role = 'owner');
$function$;

CREATE OR REPLACE FUNCTION public.join_band (
  p_code text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare inv public.band_invites;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into inv from public.band_invites
   where code = upper(trim(p_code)) and expires_at > now();
  if not found then raise exception 'invalid or expired invite code'; end if;
  insert into public.band_members(band_id, user_id, role) values (inv.band_id, auth.uid(), inv.role)
  on conflict do nothing;   -- someone already in the band keeps their current level
  return inv.band_id;
end $function$;

REVOKE ALL ON FUNCTION "public"."join_band"(text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.log_change()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
    if not exists (select 1 from public.bands where id = old.band_id) then
      return old;  -- the whole band is being deleted, so there is nothing to keep a history for
    end if;
    insert into public.change_log(band_id, table_name, row_id, op, old_data)
    values (old.band_id, tg_table_name, old.id, 'DELETE', to_jsonb(old));
    return old;
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.purge_band_log()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  delete from public.change_log where band_id = old.id;
  return old;
end $function$;

CREATE OR REPLACE FUNCTION public.remove_member (
  p_band uuid,
  p_user uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare me text; target text;
begin
  select role into me from public.band_members where band_id = p_band and user_id = auth.uid();
  if me is null then raise exception 'You are not in this band'; end if;
  select role into target from public.band_members where band_id = p_band and user_id = p_user;
  if target is null then raise exception 'That person is not in this band'; end if;
  if target = 'owner' then raise exception 'The owner cannot be removed and cannot leave the band'; end if;
  if p_user <> auth.uid() and me not in ('owner','admin') then
    raise exception 'Only owners and admins can remove other people';
  end if;
  delete from public.band_members where band_id = p_band and user_id = p_user;
end $function$;

REVOKE ALL ON FUNCTION "public"."remove_member"(uuid, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.set_member_role (
  p_band uuid,
  p_user uuid,
  p_role text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare me text; target text;
begin
  select role into me from public.band_members where band_id = p_band and user_id = auth.uid();
  if me is null or me not in ('owner','admin') then
    raise exception 'Only owners and admins can change access levels';
  end if;
  if p_role not in ('admin','editor','viewer') then
    raise exception 'Access level must be admin, editor or viewer';
  end if;
  select role into target from public.band_members where band_id = p_band and user_id = p_user;
  if target is null then raise exception 'That person is not in this band'; end if;
  if target = 'owner' then raise exception 'The owner''s access level cannot be changed'; end if;
  update public.band_members set role = p_role where band_id = p_band and user_id = p_user;
end $function$;

REVOKE ALL ON FUNCTION "public"."set_member_role"(uuid, uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.shares_band_with (
  u uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.band_members mine
    join public.band_members theirs on theirs.band_id = mine.band_id
    where mine.user_id = auth.uid() and theirs.user_id = u
  );
$function$;

CREATE OR REPLACE FUNCTION public.touch_row()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at = now();
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.transfer_ownership (
  p_band uuid,
  p_user uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare me text; target text;
begin
  select role into me from public.band_members where band_id = p_band and user_id = auth.uid();
  if me is distinct from 'owner' then raise exception 'Only the owner can transfer ownership'; end if;
  if p_user = auth.uid() then raise exception 'You are already the owner'; end if;
  select role into target from public.band_members where band_id = p_band and user_id = p_user;
  if target is null then raise exception 'That person is not in this band'; end if;
  update public.band_members set role = 'admin' where band_id = p_band and user_id = auth.uid();
  update public.band_members set role = 'owner' where band_id = p_band and user_id = p_user;
end $function$;

REVOKE ALL ON FUNCTION "public"."transfer_ownership"(uuid, uuid) FROM PUBLIC, "anon";

ALTER TABLE "public"."band_invites"
  ADD CONSTRAINT "band_invites_band_id_fkey" FOREIGN KEY (band_id) REFERENCES public.bands(id) ON DELETE CASCADE;

ALTER TABLE "public"."band_members"
  ADD CONSTRAINT "band_members_band_id_fkey" FOREIGN KEY (band_id) REFERENCES public.bands(id) ON DELETE CASCADE;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."band_invites"
  ADD CONSTRAINT "band_invites_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."band_members"
  ADD CONSTRAINT "band_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."bands"
  ADD CONSTRAINT "bands_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."setlists"
  ADD CONSTRAINT "setlists_band_id_fkey" FOREIGN KEY (band_id) REFERENCES public.bands(id) ON DELETE CASCADE;

ALTER TABLE "public"."setlists"
  ADD CONSTRAINT "setlists_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."setlist_songs"
  ADD CONSTRAINT "setlist_songs_setlist_id_band_id_fkey" FOREIGN KEY (setlist_id, band_id) REFERENCES public.setlists(id, band_id) ON DELETE CASCADE;

ALTER TABLE "public"."band_members"
  ADD CONSTRAINT "band_members_last_setlist_id_fkey" FOREIGN KEY (last_setlist_id) REFERENCES public.setlists(id) ON DELETE SET NULL;

ALTER TABLE "public"."song_links"
  ADD CONSTRAINT "song_links_added_by_fkey" FOREIGN KEY (added_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."song_views"
  ADD CONSTRAINT "song_views_band_id_fkey" FOREIGN KEY (band_id) REFERENCES public.bands(id) ON DELETE CASCADE;

ALTER TABLE "public"."song_views"
  ADD CONSTRAINT "song_views_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."songs"
  ADD CONSTRAINT "songs_band_id_fkey" FOREIGN KEY (band_id) REFERENCES public.bands(id) ON DELETE CASCADE;

ALTER TABLE "public"."songs"
  ADD CONSTRAINT "songs_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."setlist_songs"
  ADD CONSTRAINT "setlist_songs_song_id_band_id_fkey" FOREIGN KEY (song_id, band_id) REFERENCES public.songs(id, band_id) ON DELETE CASCADE;

ALTER TABLE "public"."song_links"
  ADD CONSTRAINT "song_links_song_id_band_id_fkey" FOREIGN KEY (song_id, band_id) REFERENCES public.songs(id, band_id) ON DELETE CASCADE;

ALTER TABLE "public"."song_views"
  ADD CONSTRAINT "song_views_song_id_band_id_fkey" FOREIGN KEY (song_id, band_id) REFERENCES public.songs(id, band_id) ON DELETE CASCADE;

CREATE UNIQUE INDEX band_members_one_owner ON public.band_members USING btree (band_id)
  WHERE (ROLE = 'owner'::text);

CREATE INDEX band_members_user_idx ON public.band_members USING btree (user_id);

CREATE UNIQUE INDEX bands_slug_key ON public.bands USING btree (slug);

CREATE INDEX change_log_band_time_idx ON public.change_log USING btree (band_id, changed_at DESC);

CREATE INDEX change_log_row_idx ON public.change_log USING btree (table_name, row_id, changed_at DESC);

CREATE INDEX setlist_songs_band_updated_idx ON public.setlist_songs USING btree (band_id, updated_at);

CREATE INDEX setlist_songs_order_idx ON public.setlist_songs USING btree (setlist_id, "position");

CREATE INDEX setlists_band_updated_idx ON public.setlists USING btree (band_id, updated_at);

CREATE INDEX song_links_band_updated_idx ON public.song_links USING btree (band_id, updated_at);

CREATE INDEX song_links_song_idx ON public.song_links USING btree (song_id);

CREATE INDEX song_views_band_user_idx ON public.song_views USING btree (band_id, user_id);

CREATE INDEX songs_band_updated_idx ON public.songs USING btree (band_id, updated_at);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER purge_band_log
  AFTER DELETE ON public.bands
  FOR EACH ROW
  EXECUTE FUNCTION public.purge_band_log();

CREATE TRIGGER touch_bands
  BEFORE UPDATE ON public.bands
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER touch_profiles
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER log_setlist_songs
  AFTER INSERT OR DELETE OR UPDATE ON public.setlist_songs
  FOR EACH ROW
  EXECUTE FUNCTION public.log_change();

CREATE TRIGGER touch_setlist_songs
  BEFORE UPDATE ON public.setlist_songs
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER log_setlists
  AFTER INSERT OR DELETE OR UPDATE ON public.setlists
  FOR EACH ROW
  EXECUTE FUNCTION public.log_change();

CREATE TRIGGER touch_setlists
  BEFORE UPDATE ON public.setlists
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER log_song_links
  AFTER INSERT OR DELETE OR UPDATE ON public.song_links
  FOR EACH ROW
  EXECUTE FUNCTION public.log_change();

CREATE TRIGGER touch_song_links
  BEFORE UPDATE ON public.song_links
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER touch_song_views
  BEFORE UPDATE ON public.song_views
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE TRIGGER log_songs
  AFTER INSERT OR DELETE OR UPDATE ON public.songs
  FOR EACH ROW
  EXECUTE FUNCTION public.log_change();

CREATE TRIGGER touch_songs
  BEFORE UPDATE ON public.songs
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_row();

CREATE POLICY "band_invites_delete" ON "public"."band_invites"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "band_invites_insert" ON "public"."band_invites"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((public.is_band_admin(band_id) AND (created_by = auth.uid())));

CREATE POLICY "band_invites_select" ON "public"."band_invites"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "band_members_select" ON "public"."band_members"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "band_members_update_own" ON "public"."band_members"
  FOR UPDATE
  TO "authenticated"
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "bands_delete" ON "public"."bands"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_owner(id));

CREATE POLICY "bands_select" ON "public"."bands"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(id));

CREATE POLICY "bands_update" ON "public"."bands"
  FOR UPDATE
  TO "authenticated"
  USING (public.is_band_admin(id))
  WITH CHECK (public.is_band_admin(id));

CREATE POLICY "change_log_select" ON "public"."change_log"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "profiles_select" ON "public"."profiles"
  FOR SELECT
  TO "authenticated"
  USING (((id = auth.uid()) OR public.shares_band_with(id)));

CREATE POLICY "profiles_update" ON "public"."profiles"
  FOR UPDATE
  TO "authenticated"
  USING ((id = auth.uid()))
  WITH CHECK ((id = auth.uid()));

CREATE POLICY "setlist_songs_delete" ON "public"."setlist_songs"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "setlist_songs_insert" ON "public"."setlist_songs"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "setlist_songs_select" ON "public"."setlist_songs"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "setlist_songs_update" ON "public"."setlist_songs"
  FOR UPDATE
  TO "authenticated"
  USING (public.can_edit_band(band_id))
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "setlists_delete" ON "public"."setlists"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "setlists_insert" ON "public"."setlists"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "setlists_select" ON "public"."setlists"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "setlists_update" ON "public"."setlists"
  FOR UPDATE
  TO "authenticated"
  USING (public.can_edit_band(band_id))
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "song_links_delete" ON "public"."song_links"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "song_links_insert" ON "public"."song_links"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "song_links_select" ON "public"."song_links"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "song_links_update" ON "public"."song_links"
  FOR UPDATE
  TO "authenticated"
  USING (public.can_edit_band(band_id))
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "song_views_delete" ON "public"."song_views"
  FOR DELETE
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "song_views_insert" ON "public"."song_views"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = auth.uid()) AND public.is_band_member(band_id)));

CREATE POLICY "song_views_select" ON "public"."song_views"
  FOR SELECT
  TO "authenticated"
  USING (((user_id = auth.uid()) AND public.is_band_member(band_id)));

CREATE POLICY "song_views_update" ON "public"."song_views"
  FOR UPDATE
  TO "authenticated"
  USING (((user_id = auth.uid()) AND public.is_band_member(band_id)))
  WITH CHECK (((user_id = auth.uid()) AND public.is_band_member(band_id)));

CREATE POLICY "songs_delete" ON "public"."songs"
  FOR DELETE
  TO "authenticated"
  USING (public.is_band_admin(band_id));

CREATE POLICY "songs_insert" ON "public"."songs"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.can_edit_band(band_id));

CREATE POLICY "songs_select" ON "public"."songs"
  FOR SELECT
  TO "authenticated"
  USING (public.is_band_member(band_id));

CREATE POLICY "songs_update" ON "public"."songs"
  FOR UPDATE
  TO "authenticated"
  USING (public.can_edit_band(band_id))
  WITH CHECK (public.can_edit_band(band_id));

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."setlist_songs";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."setlists";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."song_links";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."songs";

GRANT EXECUTE ON FUNCTION "public"."can_edit_band"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."can_edit_band"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."can_edit_band"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."can_edit_band"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."create_band"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."create_band"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_band"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_band"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."invite_preview"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."invite_preview"(text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."invite_preview"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."invite_preview"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."invite_preview"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_band_admin"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_band_admin"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_admin"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_admin"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_band_member"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_band_member"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_member"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_member"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_band_owner"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_band_owner"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_owner"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_band_owner"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."join_band"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."join_band"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."join_band"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."join_band"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."log_change"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."log_change"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."log_change"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."log_change"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."purge_band_log"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."purge_band_log"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."purge_band_log"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."purge_band_log"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."remove_member"(uuid, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."remove_member"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."remove_member"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."remove_member"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_member_role"(uuid, uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."set_member_role"(uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_member_role"(uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_member_role"(uuid, uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."shares_band_with"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."shares_band_with"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."shares_band_with"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."shares_band_with"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."touch_row"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."touch_row"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_row"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_row"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."transfer_ownership"(uuid, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."transfer_ownership"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."transfer_ownership"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."transfer_ownership"(uuid, uuid) TO "service_role";

REVOKE ALL ON SEQUENCE "public"."change_log_id_seq" FROM "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."change_log_id_seq" TO "anon";

REVOKE ALL ON SEQUENCE "public"."change_log_id_seq" FROM "authenticated";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."change_log_id_seq" TO "authenticated";

REVOKE ALL ON SEQUENCE "public"."change_log_id_seq" FROM "postgres";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."change_log_id_seq" TO "postgres";

REVOKE ALL ON SEQUENCE "public"."change_log_id_seq" FROM "service_role";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."change_log_id_seq" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_invites" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."band_invites" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_invites" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_invites" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_members" TO "anon";

REVOKE ALL ON TABLE "public"."band_members" FROM "authenticated";

REVOKE ALL ("last_setlist_id") ON TABLE "public"."band_members" FROM "authenticated";

GRANT UPDATE ("last_setlist_id") ON TABLE "public"."band_members" TO "authenticated";

REVOKE ALL ("roles") ON TABLE "public"."band_members" FROM "authenticated";

GRANT UPDATE ("roles") ON TABLE "public"."band_members" TO "authenticated";

REVOKE ALL ("theme") ON TABLE "public"."band_members" FROM "authenticated";

GRANT UPDATE ("theme") ON TABLE "public"."band_members" TO "authenticated";

GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."band_members" TO "authenticated";

REVOKE ALL ON TABLE "public"."band_members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_members" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."band_members" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bands" TO "anon";

REVOKE ALL ON TABLE "public"."bands" FROM "authenticated";

REVOKE ALL ("logo") ON TABLE "public"."bands" FROM "authenticated";

GRANT UPDATE ("logo") ON TABLE "public"."bands" TO "authenticated";

REVOKE ALL ("name") ON TABLE "public"."bands" FROM "authenticated";

GRANT UPDATE ("name") ON TABLE "public"."bands" TO "authenticated";

REVOKE ALL ("slug") ON TABLE "public"."bands" FROM "authenticated";

GRANT UPDATE ("slug") ON TABLE "public"."bands" TO "authenticated";

REVOKE ALL ("theme") ON TABLE "public"."bands" FROM "authenticated";

GRANT UPDATE ("theme") ON TABLE "public"."bands" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."bands" TO "authenticated";

REVOKE ALL ON TABLE "public"."bands" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bands" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bands" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."change_log" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."change_log" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."change_log" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."change_log" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."profiles" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlist_songs" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."setlist_songs" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlist_songs" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlist_songs" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlists" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."setlists" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlists" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."setlists" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_links" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."song_links" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_links" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_links" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_views" TO "authenticated";

REVOKE ALL ON TABLE "public"."song_views" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_views" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."song_views" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."songs" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."songs" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."songs" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."songs" TO "service_role";

