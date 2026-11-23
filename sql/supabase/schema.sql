


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."can_edit_band"("b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.band_members
                 where band_id = b and user_id = auth.uid() and role in ('owner','admin','editor'));
$$;


ALTER FUNCTION "public"."can_edit_band"("b" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."bands" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "theme" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "logo" "text",
    "slug" "text",
    CONSTRAINT "bands_logo_check" CHECK ((("logo" IS NULL) OR (("length"("logo") <= 250000) AND ("logo" ~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$'::"text")))),
    CONSTRAINT "bands_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "name")) >= 1) AND ("char_length"(TRIM(BOTH FROM "name")) <= 80))),
    CONSTRAINT "bands_slug_check" CHECK ((("slug" IS NULL) OR (("slug" ~ '^[a-z0-9][a-z0-9-]{1,29}$'::"text") AND ("slug" <> ALL (ARRAY['join'::"text", 'invite'::"text", 'admin'::"text", 'login'::"text", 'signin'::"text", 'signup'::"text", 'new'::"text", 'api'::"text", 'app'::"text", 'settings'::"text", 'help'::"text", 'null'::"text"])))))
);


ALTER TABLE "public"."bands" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_band"("p_name" "text") RETURNS "public"."bands"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare b public.bands;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.bands(name, created_by) values (trim(p_name), auth.uid()) returning * into b;
  insert into public.band_members(band_id, user_id, role) values (b.id, auth.uid(), 'owner');
  return b;
end $$;


ALTER FUNCTION "public"."create_band"("p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invite_preview"("p_code" "text") RETURNS TABLE("band_name" "text", "role" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select b.name::text, i.role::text
    from public.band_invites i
    join public.bands b on b.id = i.band_id
   where i.code = upper(trim(p_code))
     and i.expires_at > now()
   limit 1;
$$;


ALTER FUNCTION "public"."invite_preview"("p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_band_admin"("b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.band_members
                 where band_id = b and user_id = auth.uid() and role in ('owner','admin'));
$$;


ALTER FUNCTION "public"."is_band_admin"("b" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_band_member"("b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid());
$$;


ALTER FUNCTION "public"."is_band_member"("b" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_band_owner"("b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.band_members where band_id = b and user_id = auth.uid() and role = 'owner');
$$;


ALTER FUNCTION "public"."is_band_owner"("b" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_band"("p_code" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare inv public.band_invites;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into inv from public.band_invites
   where code = upper(trim(p_code)) and expires_at > now();
  if not found then raise exception 'invalid or expired invite code'; end if;
  insert into public.band_members(band_id, user_id, role) values (inv.band_id, auth.uid(), inv.role)
  on conflict do nothing;   -- someone already in the band keeps their current level
  return inv.band_id;
end $$;


ALTER FUNCTION "public"."join_band"("p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."log_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_band_log"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  delete from public.change_log where band_id = old.id;
  return old;
end $$;


ALTER FUNCTION "public"."purge_band_log"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_member"("p_band" "uuid", "p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."remove_member"("p_band" "uuid", "p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_member_role"("p_band" "uuid", "p_user" "uuid", "p_role" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
end $$;


ALTER FUNCTION "public"."set_member_role"("p_band" "uuid", "p_user" "uuid", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shares_band_with"("u" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.band_members mine
    join public.band_members theirs on theirs.band_id = mine.band_id
    where mine.user_id = auth.uid() and theirs.user_id = u
  );
$$;


ALTER FUNCTION "public"."shares_band_with"("u" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_row"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end $$;


ALTER FUNCTION "public"."touch_row"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_ownership"("p_band" "uuid", "p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me text; target text;
begin
  select role into me from public.band_members where band_id = p_band and user_id = auth.uid();
  if me is distinct from 'owner' then raise exception 'Only the owner can transfer ownership'; end if;
  if p_user = auth.uid() then raise exception 'You are already the owner'; end if;
  select role into target from public.band_members where band_id = p_band and user_id = p_user;
  if target is null then raise exception 'That person is not in this band'; end if;
  update public.band_members set role = 'admin' where band_id = p_band and user_id = auth.uid();
  update public.band_members set role = 'owner' where band_id = p_band and user_id = p_user;
end $$;


ALTER FUNCTION "public"."transfer_ownership"("p_band" "uuid", "p_user" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."band_invites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "band_id" "uuid" NOT NULL,
    "code" "text" DEFAULT "upper"("substr"("replace"(("gen_random_uuid"())::"text", '-'::"text", ''::"text"), 1, 8)) NOT NULL,
    "created_by" "uuid" NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '7 days'::interval) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role" "text" DEFAULT 'editor'::"text" NOT NULL,
    CONSTRAINT "band_invites_role_check" CHECK (("role" = ANY (ARRAY['editor'::"text", 'viewer'::"text"])))
);


ALTER TABLE "public"."band_invites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."band_members" (
    "band_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'editor'::"text" NOT NULL,
    "theme" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "roles" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "last_setlist_id" "uuid",
    CONSTRAINT "band_members_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'admin'::"text", 'editor'::"text", 'viewer'::"text"]))),
    CONSTRAINT "band_members_roles_check" CHECK (("roles" <@ ARRAY['singer'::"text", 'guitarist'::"text", 'bassist'::"text", 'drummer'::"text", 'keyboards'::"text"]))
);


ALTER TABLE "public"."band_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."change_log" (
    "id" bigint NOT NULL,
    "band_id" "uuid" NOT NULL,
    "table_name" "text" NOT NULL,
    "row_id" "uuid" NOT NULL,
    "op" "text" NOT NULL,
    "old_data" "jsonb",
    "new_data" "jsonb",
    "changed_by" "uuid" DEFAULT "auth"."uid"(),
    "changed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reason" "text",
    CONSTRAINT "change_log_op_check" CHECK (("op" = ANY (ARRAY['INSERT'::"text", 'UPDATE'::"text", 'DELETE'::"text"])))
);


ALTER TABLE "public"."change_log" OWNER TO "postgres";


ALTER TABLE "public"."change_log" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."change_log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text" DEFAULT ''::"text" NOT NULL,
    "theme_mode" "text" DEFAULT 'system'::"text" NOT NULL,
    "theme" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "profiles_theme_mode_check" CHECK (("theme_mode" = ANY (ARRAY['light'::"text", 'dark'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."setlist_songs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "band_id" "uuid" NOT NULL,
    "setlist_id" "uuid" NOT NULL,
    "song_id" "uuid" NOT NULL,
    "position" double precision NOT NULL,
    "bpm_override" integer,
    "key_override" "text",
    "notes_override" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "setlist_songs_bpm_override_check" CHECK ((("bpm_override" >= 20) AND ("bpm_override" <= 400)))
);


ALTER TABLE "public"."setlist_songs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."setlists" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "band_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "gig_date" "date",
    "venue" "text" DEFAULT ''::"text" NOT NULL,
    "notes" "text" DEFAULT ''::"text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."setlists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."song_links" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "band_id" "uuid" NOT NULL,
    "song_id" "uuid" NOT NULL,
    "kind" "text" DEFAULT 'other'::"text" NOT NULL,
    "url" "text" NOT NULL,
    "label" "text" DEFAULT ''::"text" NOT NULL,
    "added_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "song_links_kind_check" CHECK (("kind" = ANY (ARRAY['sheet_music'::"text", 'tab'::"text", 'lyrics'::"text", 'video'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."song_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."song_views" (
    "user_id" "uuid" NOT NULL,
    "song_id" "uuid" NOT NULL,
    "band_id" "uuid" NOT NULL,
    "view" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "song_views_view_check" CHECK (("view" = ANY (ARRAY['guitar'::"text", 'bass'::"text"])))
);


ALTER TABLE "public"."song_views" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."songs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "band_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "artist" "text" DEFAULT ''::"text" NOT NULL,
    "version_label" "text" DEFAULT ''::"text" NOT NULL,
    "bpm" integer,
    "musical_key" "text",
    "time_signature" "text" DEFAULT '4/4'::"text" NOT NULL,
    "chords" "text" DEFAULT ''::"text" NOT NULL,
    "notes" "text" DEFAULT ''::"text" NOT NULL,
    "lyrics_url" "text",
    "youtube_url" "text",
    "catalog_ref" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "change_note" "text",
    "root_notes" "text" DEFAULT ''::"text" NOT NULL,
    "song_structure" "text" DEFAULT ''::"text" NOT NULL,
    CONSTRAINT "songs_bpm_check" CHECK ((("bpm" >= 20) AND ("bpm" <= 400)))
);


ALTER TABLE "public"."songs" OWNER TO "postgres";


ALTER TABLE ONLY "public"."band_invites"
    ADD CONSTRAINT "band_invites_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."band_invites"
    ADD CONSTRAINT "band_invites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."band_members"
    ADD CONSTRAINT "band_members_pkey" PRIMARY KEY ("band_id", "user_id");



ALTER TABLE ONLY "public"."bands"
    ADD CONSTRAINT "bands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."change_log"
    ADD CONSTRAINT "change_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."setlist_songs"
    ADD CONSTRAINT "setlist_songs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."setlists"
    ADD CONSTRAINT "setlists_id_band_id_key" UNIQUE ("id", "band_id");



ALTER TABLE ONLY "public"."setlists"
    ADD CONSTRAINT "setlists_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."song_links"
    ADD CONSTRAINT "song_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."song_views"
    ADD CONSTRAINT "song_views_pkey" PRIMARY KEY ("user_id", "song_id");



ALTER TABLE ONLY "public"."songs"
    ADD CONSTRAINT "songs_id_band_id_key" UNIQUE ("id", "band_id");



ALTER TABLE ONLY "public"."songs"
    ADD CONSTRAINT "songs_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "band_members_one_owner" ON "public"."band_members" USING "btree" ("band_id") WHERE ("role" = 'owner'::"text");



CREATE INDEX "band_members_user_idx" ON "public"."band_members" USING "btree" ("user_id");



CREATE UNIQUE INDEX "bands_slug_key" ON "public"."bands" USING "btree" ("slug");



CREATE INDEX "change_log_band_time_idx" ON "public"."change_log" USING "btree" ("band_id", "changed_at" DESC);



CREATE INDEX "change_log_row_idx" ON "public"."change_log" USING "btree" ("table_name", "row_id", "changed_at" DESC);



CREATE INDEX "setlist_songs_band_updated_idx" ON "public"."setlist_songs" USING "btree" ("band_id", "updated_at");



CREATE INDEX "setlist_songs_order_idx" ON "public"."setlist_songs" USING "btree" ("setlist_id", "position");



CREATE INDEX "setlists_band_updated_idx" ON "public"."setlists" USING "btree" ("band_id", "updated_at");



CREATE INDEX "song_links_band_updated_idx" ON "public"."song_links" USING "btree" ("band_id", "updated_at");



CREATE INDEX "song_links_song_idx" ON "public"."song_links" USING "btree" ("song_id");



CREATE INDEX "song_views_band_user_idx" ON "public"."song_views" USING "btree" ("band_id", "user_id");



CREATE INDEX "songs_band_updated_idx" ON "public"."songs" USING "btree" ("band_id", "updated_at");



CREATE OR REPLACE TRIGGER "log_setlist_songs" AFTER INSERT OR DELETE OR UPDATE ON "public"."setlist_songs" FOR EACH ROW EXECUTE FUNCTION "public"."log_change"();



CREATE OR REPLACE TRIGGER "log_setlists" AFTER INSERT OR DELETE OR UPDATE ON "public"."setlists" FOR EACH ROW EXECUTE FUNCTION "public"."log_change"();



CREATE OR REPLACE TRIGGER "log_song_links" AFTER INSERT OR DELETE OR UPDATE ON "public"."song_links" FOR EACH ROW EXECUTE FUNCTION "public"."log_change"();



CREATE OR REPLACE TRIGGER "log_songs" AFTER INSERT OR DELETE OR UPDATE ON "public"."songs" FOR EACH ROW EXECUTE FUNCTION "public"."log_change"();



CREATE OR REPLACE TRIGGER "purge_band_log" AFTER DELETE ON "public"."bands" FOR EACH ROW EXECUTE FUNCTION "public"."purge_band_log"();



CREATE OR REPLACE TRIGGER "touch_bands" BEFORE UPDATE ON "public"."bands" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_profiles" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_setlist_songs" BEFORE UPDATE ON "public"."setlist_songs" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_setlists" BEFORE UPDATE ON "public"."setlists" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_song_links" BEFORE UPDATE ON "public"."song_links" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_song_views" BEFORE UPDATE ON "public"."song_views" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



CREATE OR REPLACE TRIGGER "touch_songs" BEFORE UPDATE ON "public"."songs" FOR EACH ROW EXECUTE FUNCTION "public"."touch_row"();



ALTER TABLE ONLY "public"."band_invites"
    ADD CONSTRAINT "band_invites_band_id_fkey" FOREIGN KEY ("band_id") REFERENCES "public"."bands"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."band_invites"
    ADD CONSTRAINT "band_invites_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."band_members"
    ADD CONSTRAINT "band_members_band_id_fkey" FOREIGN KEY ("band_id") REFERENCES "public"."bands"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."band_members"
    ADD CONSTRAINT "band_members_last_setlist_id_fkey" FOREIGN KEY ("last_setlist_id") REFERENCES "public"."setlists"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."band_members"
    ADD CONSTRAINT "band_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bands"
    ADD CONSTRAINT "bands_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."setlist_songs"
    ADD CONSTRAINT "setlist_songs_setlist_id_band_id_fkey" FOREIGN KEY ("setlist_id", "band_id") REFERENCES "public"."setlists"("id", "band_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."setlist_songs"
    ADD CONSTRAINT "setlist_songs_song_id_band_id_fkey" FOREIGN KEY ("song_id", "band_id") REFERENCES "public"."songs"("id", "band_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."setlists"
    ADD CONSTRAINT "setlists_band_id_fkey" FOREIGN KEY ("band_id") REFERENCES "public"."bands"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."setlists"
    ADD CONSTRAINT "setlists_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."song_links"
    ADD CONSTRAINT "song_links_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."song_links"
    ADD CONSTRAINT "song_links_song_id_band_id_fkey" FOREIGN KEY ("song_id", "band_id") REFERENCES "public"."songs"("id", "band_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."song_views"
    ADD CONSTRAINT "song_views_band_id_fkey" FOREIGN KEY ("band_id") REFERENCES "public"."bands"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."song_views"
    ADD CONSTRAINT "song_views_song_id_band_id_fkey" FOREIGN KEY ("song_id", "band_id") REFERENCES "public"."songs"("id", "band_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."song_views"
    ADD CONSTRAINT "song_views_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."songs"
    ADD CONSTRAINT "songs_band_id_fkey" FOREIGN KEY ("band_id") REFERENCES "public"."bands"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."songs"
    ADD CONSTRAINT "songs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE "public"."band_invites" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "band_invites_delete" ON "public"."band_invites" FOR DELETE TO "authenticated" USING ("public"."is_band_admin"("band_id"));



CREATE POLICY "band_invites_insert" ON "public"."band_invites" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_band_admin"("band_id") AND ("created_by" = "auth"."uid"())));



CREATE POLICY "band_invites_select" ON "public"."band_invites" FOR SELECT TO "authenticated" USING ("public"."is_band_admin"("band_id"));



ALTER TABLE "public"."band_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "band_members_select" ON "public"."band_members" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



CREATE POLICY "band_members_update_own" ON "public"."band_members" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."bands" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bands_delete" ON "public"."bands" FOR DELETE TO "authenticated" USING ("public"."is_band_owner"("id"));



CREATE POLICY "bands_select" ON "public"."bands" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("id"));



CREATE POLICY "bands_update" ON "public"."bands" FOR UPDATE TO "authenticated" USING ("public"."is_band_admin"("id")) WITH CHECK ("public"."is_band_admin"("id"));



ALTER TABLE "public"."change_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "change_log_select" ON "public"."change_log" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) OR "public"."shares_band_with"("id")));



CREATE POLICY "profiles_update" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));



ALTER TABLE "public"."setlist_songs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "setlist_songs_delete" ON "public"."setlist_songs" FOR DELETE TO "authenticated" USING ("public"."is_band_admin"("band_id"));



CREATE POLICY "setlist_songs_insert" ON "public"."setlist_songs" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_edit_band"("band_id"));



CREATE POLICY "setlist_songs_select" ON "public"."setlist_songs" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



CREATE POLICY "setlist_songs_update" ON "public"."setlist_songs" FOR UPDATE TO "authenticated" USING ("public"."can_edit_band"("band_id")) WITH CHECK ("public"."can_edit_band"("band_id"));



ALTER TABLE "public"."setlists" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "setlists_delete" ON "public"."setlists" FOR DELETE TO "authenticated" USING ("public"."is_band_admin"("band_id"));



CREATE POLICY "setlists_insert" ON "public"."setlists" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_edit_band"("band_id"));



CREATE POLICY "setlists_select" ON "public"."setlists" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



CREATE POLICY "setlists_update" ON "public"."setlists" FOR UPDATE TO "authenticated" USING ("public"."can_edit_band"("band_id")) WITH CHECK ("public"."can_edit_band"("band_id"));



ALTER TABLE "public"."song_links" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "song_links_delete" ON "public"."song_links" FOR DELETE TO "authenticated" USING ("public"."is_band_admin"("band_id"));



CREATE POLICY "song_links_insert" ON "public"."song_links" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_edit_band"("band_id"));



CREATE POLICY "song_links_select" ON "public"."song_links" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



CREATE POLICY "song_links_update" ON "public"."song_links" FOR UPDATE TO "authenticated" USING ("public"."can_edit_band"("band_id")) WITH CHECK ("public"."can_edit_band"("band_id"));



ALTER TABLE "public"."song_views" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "song_views_delete" ON "public"."song_views" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "song_views_insert" ON "public"."song_views" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."is_band_member"("band_id")));



CREATE POLICY "song_views_select" ON "public"."song_views" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND "public"."is_band_member"("band_id")));



CREATE POLICY "song_views_update" ON "public"."song_views" FOR UPDATE TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND "public"."is_band_member"("band_id"))) WITH CHECK ((("user_id" = "auth"."uid"()) AND "public"."is_band_member"("band_id")));



ALTER TABLE "public"."songs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "songs_delete" ON "public"."songs" FOR DELETE TO "authenticated" USING ("public"."is_band_admin"("band_id"));



CREATE POLICY "songs_insert" ON "public"."songs" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_edit_band"("band_id"));



CREATE POLICY "songs_select" ON "public"."songs" FOR SELECT TO "authenticated" USING ("public"."is_band_member"("band_id"));



CREATE POLICY "songs_update" ON "public"."songs" FOR UPDATE TO "authenticated" USING ("public"."can_edit_band"("band_id")) WITH CHECK ("public"."can_edit_band"("band_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."setlist_songs";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."setlists";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."song_links";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."songs";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."can_edit_band"("b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_edit_band"("b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_edit_band"("b" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."bands" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."bands" TO "authenticated";
GRANT ALL ON TABLE "public"."bands" TO "service_role";



GRANT UPDATE("name") ON TABLE "public"."bands" TO "authenticated";



GRANT UPDATE("theme") ON TABLE "public"."bands" TO "authenticated";



GRANT UPDATE("logo") ON TABLE "public"."bands" TO "authenticated";



GRANT UPDATE("slug") ON TABLE "public"."bands" TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_band"("p_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_band"("p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_band"("p_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."invite_preview"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invite_preview"("p_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."invite_preview"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."invite_preview"("p_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_band_admin"("b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_band_admin"("b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_band_admin"("b" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_band_member"("b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_band_member"("b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_band_member"("b" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_band_owner"("b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_band_owner"("b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_band_owner"("b" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."join_band"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."join_band"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_band"("p_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."purge_band_log"() TO "anon";
GRANT ALL ON FUNCTION "public"."purge_band_log"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."purge_band_log"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_member"("p_band" "uuid", "p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_member"("p_band" "uuid", "p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_member"("p_band" "uuid", "p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_member_role"("p_band" "uuid", "p_user" "uuid", "p_role" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_member_role"("p_band" "uuid", "p_user" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_member_role"("p_band" "uuid", "p_user" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."shares_band_with"("u" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."shares_band_with"("u" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."shares_band_with"("u" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_row"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_row"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_row"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."transfer_ownership"("p_band" "uuid", "p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."transfer_ownership"("p_band" "uuid", "p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_ownership"("p_band" "uuid", "p_user" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."band_invites" TO "anon";
GRANT ALL ON TABLE "public"."band_invites" TO "authenticated";
GRANT ALL ON TABLE "public"."band_invites" TO "service_role";



GRANT ALL ON TABLE "public"."band_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."band_members" TO "authenticated";
GRANT ALL ON TABLE "public"."band_members" TO "service_role";



GRANT UPDATE("theme") ON TABLE "public"."band_members" TO "authenticated";



GRANT UPDATE("roles") ON TABLE "public"."band_members" TO "authenticated";



GRANT UPDATE("last_setlist_id") ON TABLE "public"."band_members" TO "authenticated";



GRANT ALL ON TABLE "public"."change_log" TO "anon";
GRANT ALL ON TABLE "public"."change_log" TO "authenticated";
GRANT ALL ON TABLE "public"."change_log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."change_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."change_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."change_log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."setlist_songs" TO "anon";
GRANT ALL ON TABLE "public"."setlist_songs" TO "authenticated";
GRANT ALL ON TABLE "public"."setlist_songs" TO "service_role";



GRANT ALL ON TABLE "public"."setlists" TO "anon";
GRANT ALL ON TABLE "public"."setlists" TO "authenticated";
GRANT ALL ON TABLE "public"."setlists" TO "service_role";



GRANT ALL ON TABLE "public"."song_links" TO "anon";
GRANT ALL ON TABLE "public"."song_links" TO "authenticated";
GRANT ALL ON TABLE "public"."song_links" TO "service_role";



GRANT ALL ON TABLE "public"."song_views" TO "authenticated";
GRANT ALL ON TABLE "public"."song_views" TO "service_role";



GRANT ALL ON TABLE "public"."songs" TO "anon";
GRANT ALL ON TABLE "public"."songs" TO "authenticated";
GRANT ALL ON TABLE "public"."songs" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































