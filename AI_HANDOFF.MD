# Development handoff

A status snapshot for whoever picks this work up next (a person or an AI). Last updated: November 2026.
Read `AGENTS.md` for the rules, `docs/architecture.md` for the design and `docs/roadmap.md` for the plan.

## Note on the earlier version of this file
The earlier handoff described a React, Vite and Tailwind prototype, a `changes` table with patch and inverse columns,
Supabase realtime channels, and a refactor of `SetlistManager.tsx`. None of that matches the live app, which is a
single `index.html` in plain JavaScript, with history written by a database trigger and no realtime subscription. Those
parts were removed. If files like `useLiveSync.ts` or `SetlistManager.tsx` exist under `prototype/`, treat them as
experiments, not as the live app, and check with Tim before building on them.

## 1. What exists
- **Live app:** `docs/setlist-pwa-v2/` (`index.html`, `config.js`, `sw.js`, manifest, icons), served by GitHub Pages at
  https://timlawless.github.io/setlists/setlist-pwa-v2/
- **Backend:** one Supabase project. Postgres with row-level security, Auth, and one Edge Function (`lookup-song`).
- **Database files:** v1 to v7 plus `check_schema`, run in order in the SQL Editor (listed in `docs/architecture.md`).
- **`core/`:** a tested TypeScript library from the earlier plan. The web app does not use it yet.
- **`prototype/`:** a UI prototype with sample data. A reference only.

## 2. Features built
Sign-in (email and password, emailed codes, reset), bands with owner, admin, editor and viewer levels, invite codes,
members screen, transfer of ownership, instrument roles, gig mode, songs with all fields and links, setlist screen with
reordering, song library with search, setlist rename, duplicate and delete, owner-only band delete, change history with
reasons, key and BPM lookup (function built, key not received), band colour and logo, metronome with iOS audio fix and
limited flash, offline reading, offline editing with sync.

## 3. State of the work
- **On the site and confirmed by Tim:** everything up to delete song (SQL v1 to v6).
- **Built, not yet confirmed on the site:** the sign-in codes, reset and logo update (SQL v7; needs an email service
  connected in Supabase first), and the offline editing and flash limit update (one `index.html`, no SQL).
- **Waiting:** the GetSongBPM API key (the documentation says a key is required, and a link back, which is in place).
  The lookup no longer depends on it: the Edge Function falls back to Song Finder (built, not yet tested from the live site).
- **Not built:** Google sign-in, iPhone install guide, tablet two-pane layout, history restore, MusicBrainz and
  merging lookup sources, full lyrics text, per-band app icon, band links, high-contrast mode.

## 4. Next tasks, in order
1. Help Tim finish the email setup and test reset and sign-in codes in the installed iPhone app.
2. Test offline editing on real devices (airplane mode, then a deliberate conflict from a second account).
3. Apply `cleanLink` to every stored link (a gap against `AGENTS.md`). Port the rule from `core/` and test it.
4. Put the SQL files, `check_schema.sql` and the permission and sync tests into the repository (`sql/`).
5. iPhone install guide, tablet two-pane layout, then Google sign-in.

## 5. Things learned the hard way
- Use `@supabase/supabase-js@2` from the CDN. An older pinned version rejected the newer `sb_publishable_` keys and
  reported it as "invalid login credentials" or "failed to fetch".
- The Edge Function needs Verify JWT off and checks the caller itself with `getUser`.
- Row-level security makes a forbidden update succeed with zero rows, not an error. Check the row count.
- Run SQL before uploading the page that needs it, or the page cannot load the new columns.
- Supabase's built-in email sender only reaches team members and allows about 2 emails an hour. Real users need SMTP.
- On iPhone, a link opens in Safari, not the installed app, so emails use codes. The click is muted by the silent
  switch unless the audio session is set to playback with a looping silent audio element. There is no install button;
  people must use Share, then Add to Home Screen.
- `supabase-js` can announce a sign-in again when the tab regains focus. Reloading on that event discards unsaved edits,
  so reload only when the user id changes.
- The database trigger that records history also fires for rows removed by a band delete. It skips them, and a second
  trigger removes the band's history. A test caught this; keep the test.
- Deleting a band cascades, so use a typed confirmation.
- GitHub Pages cannot route paths such as `/band-name`. Use a `#` link, or move the hosting.
- Chrome on a laptop had its own volume set to zero in the system mixer, which looked like an app bug.
- Everything in `docs/` is public.

## 6. How to work with Tim
- Tim is an experienced IT professional and a teacher. He prefers step by step work and asks for outputs he can use
  straight away.
- Deliver complete replacement files and exact steps: SQL Editor first, then the upload, and what to leave alone
  (`config.js`). He uploads through GitHub's web interface.
- Say plainly what was tested and what was not. Never claim a device behaviour works without a real device.
- Offer a recommendation and a default, then ask one question at a time when something needs deciding.
- Keep the roadmap and architecture documents in step with every change.

## 7. Open decisions
Web address and hosting (GitHub Pages, or a new domain), same-field conflict rule (ask, current, or later change wins),
Google and Apple sign-in, how to rank "well known" song versions, pruning of removed songs and old history, and how long
to keep history on the device.
