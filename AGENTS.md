# Notes for AI coding agents and new contributors

## What this is
A free, non-commercial web app (PWA) for bands: setlists with tempo, key, chords, notes, lyrics links and links, a
metronome with an optional flash, gig mode, several setlists per band, several bands per user, change history, and
offline use. Used on iPhone, Android and tablets. Backend is Supabase. The live app is a single page,
`docs/setlist-pwa-v2/index.html`, served by GitHub Pages. PWA first is decided; Expo is parked.

## Start here
1. Read `docs/architecture.md` (decisions and reasons) and `docs/roadmap.md` (what to do next).
2. Run `cd core && npm install && npm test && npm run typecheck`. All must pass before and after a change to `core/`.
3. Tick off roadmap items and update the docs when a decision changes. Keep commits small, messages in the imperative.
4. Before changing the database, read the SQL files in `sql/` in order and run `check_schema.sql` to see what is installed.

## Rules that must not be broken
- **Lyrics.** Never add, fetch, scrape or generate song lyrics. The app only stores a link and, later, text that band
  members type or paste themselves. Do not put lyrics in sample data, tests or docs.
- **Privacy.** A band's data is visible to its members only, enforced on the server with Supabase row-level security.
  Never rely on the client to hide data. Every policy needs a test that proves an outsider gets nothing, and that
  each access level can do only what it should.
- **Links.** Every stored URL goes through `cleanLink` (http and https only; unwraps Google redirect links; strips
  tracking). Never render a link that has not been cleaned.
- **History.** Every edit to a song is recorded with an author. Restores are new changes. Never rewrite history.
- **Ids** are random UUIDs, so devices never clash. New rows made offline get their id on the device.
- **`core/` is platform-free.** No React, DOM or native APIs. Inject storage and clocks.
- **Tempo and key data is unreliable.** Show a confidence level; the band's own values always win.
- **Flash.** At most three flashes a second (`flashAllowed` in `core/`; the web app has the same rule). Warn the first
  time it is switched on.
- **Secrets.** Never commit a service-role or secret key, or the GetSongBPM key. The publishable key in `config.js` is
  public by design. Do not put SQL files, keys or notes you want private in `docs/`, which is published on the web.
- **SQL.** Every SQL file is numbered, safe to run twice, and adds to what exists. Run it before uploading a page
  that depends on it. A change to permissions needs tests that were run, not just written.
- **Do not claim something works unless it was tested.** Device-specific behaviour (iPhone PWA audio, wake lock,
  offline) must be tested on real devices. Say plainly what was and was not tested.

## Known gaps against these rules (as of November 2026)
These are being worked on. Do not copy the gap into new code.
- **Links:** the web app only checks for http and https. It does not yet unwrap Google redirect links or strip tracking.
- **Confidence:** looked-up tempo and key are shown without a confidence level.
- **History restore:** history is recorded, but there is no Restore button.
- **Tests:** the permission tests and the sync tests were run on a local Postgres and in Node, but are not in the repository.
- **`core/`:** the web app does not use it yet; the metronome scheduler, queue and flash rule were rewritten in the page.

## How changes are delivered
Tim uploads files through GitHub's web interface and runs SQL in the Supabase SQL Editor. So deliver complete
replacement files plus exact steps: which SQL to run first, which file to upload, and what to leave alone
(`config.js`). Do not hand over fragments or diffs. Say when a step is an Edge Function deploy and not a SQL file.

## How the app is built
- One `index.html` holds the interface and logic as a single module. It loads supabase-js version 2 from a CDN. Keep it
  at `@2`: older pinned versions do not understand the newer `sb_publishable_` keys.
- `sw.js` serves app files network first and the library cache first, and never caches calls to Supabase.
- Reads are cached in `localStorage` for offline use. Edits go through a queue that applies them to the screen at once
  and syncs them later. Online-only: creating, renaming, duplicating and deleting setlists, band settings, members, invites.
- Permissions are enforced by row-level security and database functions. See "Access control" in `docs/architecture.md`.

## The prototype
`prototype/Main.dc.html` is the UI reference, in a design-canvas format that needs a runtime not included here.
Read its `<script>` section for behaviour and data shapes. All data in it is sample data. It is not the live app.

## Decisions so far
Supabase backend; free and never commercial; PWA first; songs belong to the band and changes apply in every setlist;
four access levels (owner, admin, editor, viewer) separate from instrument roles; emails carry codes, not links; lyrics
stay a link for now; same-field conflicts after offline editing are shown to the person to resolve; offline matters;
tablets supported (two-pane layout still to build). Open questions are at the bottom of `docs/architecture.md`.
