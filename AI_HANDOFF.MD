# Development handoff

A status snapshot for whoever picks this work up next (a person or an AI). Last updated: November 2026, after the guitar or
bass view and progression searches, the Use-saves-at-once change, the Spotify and Moises links (SQL v12), role-based gig mode (SQL v13), the role-ordered Details view, the Settings changes, roles under Band members with Back buttons, and reason-only notes (SQL v15).
Read `AGENTS.md` for the rules, `docs/architecture.md` for the design and `docs/roadmap.md` for the plan.
This file is updated with every set of files, together with the roadmap, the architecture notes and the commit message.
If it disagrees with the repository, the repository wins: correct this file.

## Note on the earlier version of this file
The earlier handoff described a React, Vite and Tailwind prototype, a `changes` table with patch and inverse columns,
Supabase realtime channels, and a refactor of `SetlistManager.tsx`. None of that matches the live app, which is a
single `index.html` in plain JavaScript, with history written by a database trigger and no realtime subscription. Those
parts were removed. If files like `useLiveSync.ts` or `SetlistManager.tsx` exist under `prototype/`, treat them as
experiments, not as the live app, and check with Tim before building on them.

## 0. Branches and delivery
- Tim and others work on different areas on different branches. Changes from the assistant are uploaded to the
  `claude-dev` branch and then merged into `main`. Codex is also used for some tasks, for example a deployment update
  (already merged) that gives the branches separate live addresses.
- Always start from the current repository files, never from an older upload or a copy kept in a chat project: those copies
  have been stale before (`index.html` and the docs). If the current file is not available, ask for it.
- Repository files use Windows (CRLF) line endings. Keep them when editing and check the diff shows only the intended lines.
- Tim uploads files through GitHub's web interface and runs SQL in the Supabase SQL Editor.

## 1. What exists
- **Live app:** `app/` (`index.html`, `config.js`, `sw.js`, manifest, icons), served by GitHub Pages at
  https://timlawless.github.io/setlists/
- **Backend:** one Supabase project. Postgres with row-level security, Auth, and two Edge Functions: `lookup-song` (tempo and
  key, GetSongBPM key optional, Song Finder as the backup) and `find-lyrics-link` (suggests a Genius page, secret
  `GENIUS_ACCESS_TOKEN`). Both have Verify JWT off and check the caller themselves.
- **Database files:** Codex contains v1, v2, v9-v11 and v14; historical v3-v8 and `check_schema.sql` are missing. Main adds v12 (`songs.spotify_url` and `songs.moises_url`), v13 (the `backing` instrument role) and v15 (`add_song_note`, for reason-only notes). Codex v14 adds offline operation receipts and supports queued reason-only notes through `add_song_note`. Confirm the existing schema and v12/v13 before applying migrations. Apply v15 before v14, because v14 calls `add_song_note`. See `docs/architecture.md`.
- **`core/`:** a tested TypeScript library from the earlier plan. The web app does not use it yet.
- **`prototype/`:** a UI prototype with sample data. A reference only.

## 2. Features built
Sign-in (email and password, emailed codes, reset), a two-choice welcome screen, invite links and an accept-invitation page,
standing invite codes, bands with owner, admin, editor and viewer levels, band links (`#ending`), members screen, transfer of
ownership, instrument roles, gig mode, songs with all fields and links, Song structure (free text), setlist screen with
reordering, song library with search, setlist rename, duplicate and delete, owner-only band delete, change history with
reasons, key and BPM lookup (Song Finder, GetSongBPM when a key exists), lyrics link suggestions, band colour and logo,
metronome with iOS audio fix, beat dots and limited flash, offline reading, offline editing with sync, install help for
iPhone and Android, small-phone layout, two-pane or one-pane layout on wide screens with a compact right-hand panel.
- **Guitar or bass view (SQL v11):** the progression box has a Guitar chords / Bass line switch. Guitar edits `songs.chords`;
  bass edits `songs.root_notes` (the old Root notes column, brought back as the Bass line). The view is remembered per person
  and song (default bass for bassists, guitar for everyone else; anyone can switch on any song), stored in `song_views` with a
  copy on the device. Gig mode has the same switch for guitarists, keyboards and bassists.
- **Progression link finder:** Find chords link / Find bass tab link lists four searches with the quoted, tidied title and artist: Google limited to Ultimate Guitar, Songsterr or Chordify, a plain Google search and, for bass, a YouTube lesson search. The artist must be filled in first.
  Open goes to a new page; Use (editors) puts the link in the box and saves it at once, after asking if something is already
  written there. Nothing is fetched. The lyrics finder behaves the same way: Use saves at once, with the same question.
- A box that holds just one link shows a larger Open button beside its label, "Chords: link" on song rows, and an Open
  button in gig mode.
- **Listen links (SQL v12):** a song has YouTube (the older box), Spotify and Moises link boxes, shared by the band, each with a
  large Open button beside a stored link. Spotify and Moises entries go through `cleanLink` (Spotify's `si` tracking dropped); a bad
  entry is refused. Moises is pasted by hand (the app cannot see a Moises library). Gig mode has a Listen panel: Moises version,
  YouTube, Spotify, only the ones that exist.
- **Role-based gig mode (SQL v13):** each role puts its own fields first. Singer: Lyrics, Key, Structure. Guitarist and Keyboards: Chords,
  Key, Structure, BPM. Bassist: Chords (bass line by default), Key, BPM. Drummer: BPM, Time, Structure, Notes. Backing singer (new role,
  `backing`, used with another role) adds the lyrics after the other fields. Roles merge in the order of the roles list. Other fields
  that have something in them wait under a collapsed More fields bar.
- **Role-ordered Details view:** the first rows (Title to Key) are the same for everyone. After Key the lyrics link, progression,
  structure and notes follow the role order from gig mode (without Key, BPM and Time, which are in the grid), then the rest in the
  usual order. `detailOrder(roles)` holds the rule so it can change later. No SQL.
- **Settings:** Band settings (name, link ending, colour, logo, delete band) has its own screen opened from the menu, for owners and
  admins; Band members and access keeps the list, invites and Leave. Every person can change their own name (Edit name on their row, or
  Your name in the Account section); it is written to their own `profiles` row, so no SQL was needed. My roles in this band is now under Band members and access, and Band members and Band settings each have a Back button to the menu.
- **Reason-only notes (SQL v15):** a reason typed with no other change is sent as a `note` item through the offline queue to
  `add_song_note(song, note)`, which adds a new History entry ("Note added") without touching the song or rewriting history.
- The GetSongBPM link was removed from the footer while no key is in use.

## 3. State of the work
`docs/roadmap.md`, "In progress and waiting", is the authoritative list of what is installed and what is awaiting review.
- **Tried by Tim and reported working:** the iPhone install test, and the recent sets: SQL v11 to v13 (guitar or bass view, Spotify and Moises links, role-based gig mode with the Backing singer role), Use saving at once, and the Open button. Tim says it all works, but the views have become busy and need tidying later.
- **Delivered, not yet confirmed on real devices:**
  the compact right-hand panel, Song structure (SQL v10), lyrics link suggestions (needs the `find-lyrics-link` function
  deployed and `GENIUS_ACCESS_TOKEN` saved), the progression link finder, and the earlier items listed in the roadmap
  (offline editing, flash limit, sign-in and invite changes, launch speed, install help).
- **Paused by Tim:** layout tweaks to the song details and gig mode. Tim finds the views messier after the recent additions. He will return to them once all functionality is in place. The Open button was reduced slightly after a first look.
- **Delivered, awaiting review:** the role-ordered Details view, the Settings changes (Band settings screen, editable own name), roles under Band members with Back buttons, and reason-only notes (SQL v15: run it first). The Details view and Settings changes are one `index.html`, no SQL.
- **Not yet reported on:** the tighter progression searches (roadmap backlog 29). Whether they reach the right song is still unknown.
- **Waiting:** the email service for reset and sign-in codes (SQL v7 needs it), the GetSongBPM API key, and a second lookup
  source for songs Song Finder cannot find.
- **Not built:** Google sign-in, history restore, MusicBrainz and merging lookup sources, full lyrics text, per-band app icon,
  high-contrast mode, a separate progression link field beside the manual chords and bass line, `cleanLink` on every stored link (the new Spotify and Moises boxes use it; lyrics and YouTube links do not yet), automatic finding of the most popular YouTube and Spotify link.

## 4. Next tasks, in order
1. Test the latest changes on real devices: the guitar or bass switch and Use in the right-hand panel and the phone layout,
   the overwrite question, the Open button size, gig mode, and the compact panel on a real desktop.
2. Help Tim finish the email setup and test reset and sign-in codes in the installed iPhone app.
3. Test offline editing on real devices (airplane mode, then a deliberate conflict from a second account).
4. Apply `cleanLink` to every stored link (a gap against `AGENTS.md`). The page already uses it for suggested links.
5. Restore the missing v3-v8 migration files and `check_schema.sql`, and put the earlier permission tests in the repository. The v11 tests were run on an in-memory Postgres and are not stored yet. The offline queue/state tests are stored; live SQL integration still needs a non-production Supabase run.
6. Check the tighter progression searches on real songs (roadmap backlog 29, step 1 built). If they still miss, build step 2: a function that finds specific videos.
7. Decide whether a progression link needs its own field, then Google sign-in and history restore.
8. Listen links stage 2: a `find-listen-link` function that finds the most popular YouTube video and Spotify track for a song, with Use saving at once and the overwrite question, always overridable by hand. It needs a YouTube Data API key and a Spotify client ID and secret as Supabase secrets.
9. Check role-based gig mode on a real phone and tablet (sideways on a music stand), with each role and with two roles, and tune the order if the band wants it different. Do the same for the role-ordered Details view. Also check that saving your own name works against the real database.
10. Confirm that a reason typed WITH a change shows in History on the real database (the History trigger may have lost the copy in a later SQL file), and investigate why one save writes two History rows for the same song a fraction of a second apart. The three read-only queries are in the roadmap, item 15.
11. Update `docs/tester-guide.md` and `docs/go-live-checklist.md`: they still say instrument roles are chosen in the menu.
## 5. Things learned the hard way
- Use `@supabase/supabase-js@2` from the CDN. An older pinned version rejected the newer `sb_publishable_` keys and
  reported it as "invalid login credentials" or "failed to fetch".
- The Edge Functions need Verify JWT off and check the caller themselves with `getUser`.
- Row-level security makes a forbidden update succeed with zero rows, not an error. Check the row count.
- Run SQL before uploading the page that needs it, or the page cannot load the new columns. The guitar or bass view is the
  exception: until v11 is run the choice waits on the device and nothing breaks.
- Supabase's built-in email sender only reaches team members and allows about 2 emails an hour. Real users need SMTP.
- On iPhone, a link opens in Safari, not the installed app, so emails use codes. The click is muted by the silent
  switch unless the audio session is set to playback with a looping silent audio element. There is no install button;
  people must use Share, then Add to Home Screen.
- `supabase-js` can announce a sign-in again when the tab regains focus. Reloading on that event discards unsaved edits,
  so reload only when the user id changes.
- The page reloads from the server after a sync finishes, unless the person is typing in the song. An unsaved edit elsewhere
  in the panel can be lost on that reload. Use on a suggestion therefore clicks the normal Save, which saves everything typed.
- The database trigger that records history also fires for rows removed by a band delete. It skips them, and a second
  trigger removes the band's history. A test caught this; keep the test.
- Deleting a band cascades, so use a typed confirmation.
- GitHub Pages cannot route paths such as `/band-name`. Use a `#` link, or move the hosting.
- Chrome on a laptop had its own volume set to zero in the system mixer, which looked like an app bug.
- Reading a repo file in Python text mode turns CRLF into LF without warning. Open with `newline=''` (or in binary) so the file keeps its line endings.
- The History trigger ignores an update where only `songs.change_note` changed, so a reason alone is never logged by it. Use `add_song_note` (SQL v15) for that, and never rewrite earlier History entries.
- Two branches change the offline code in the single `index.html` (this one added the `note` queue item; Codex has offline changes with SQL v14). A merge on GitHub can silently keep one version of a changed function. Read the queue, `runOp`, `flush` and the cached reads after merging, and test offline editing again.
- Everything in `app/` is public.
- Testing available to the assistant: an in-memory Postgres (PGlite) with a stand-in for Supabase auth for SQL and row-level
  security, and a simulated browser (jsdom) with a stand-in database for page logic. There is no real browser, phone, tablet or
  Supabase project. In the stand-in, a saved edit comes back as a conflict, so read both the queue and the issues lists.

## 6. How to work with Tim
- Tim is an experienced IT professional and a teacher. He prefers step by step work and asks for outputs he can use
  straight away.
- Before starting a request, label it small, medium or large, and ask first if it is large. Ask one question at a time.
- Deliver complete replacement files and exact steps: SQL Editor first, then the upload, and what to leave alone
  (`config.js`). Files go to the `claude-dev` branch.
- With every set of files, give a detailed git-style commit message: a short summary line, then an extended description with the
  changes in each file and what was tested and not tested.
- With every set of files, update `docs/roadmap.md`, `docs/architecture.md` and this file, and check them against the repository.
  Tim will adjust the details of this workflow.
- When asking a question about the working document of requests, quote the exact lines it is about, with the lines around them.
- Say plainly what was tested and what was not. Never claim a device behaviour works without a real device.
- Offer a recommendation and a default, then ask one question at a time when something needs deciding.

## 7. Open decisions
Web address and hosting (GitHub Pages, or a new domain), same-field conflict rule (ask, current, or later change wins),

### Longer-term product questions
- Google and Apple sign-in.
- How to rank well-known song versions and define the "most popular" version for automatic YouTube and Spotify searches.
- Pruning removed songs and old history, and deciding how long to retain history on the device.
- Whether a progression link needs its own field alongside manual chords and bass lines, and how to improve progression suggestions so they identify the correct song.
- Whether other instrument roles also want the time signature displayed in gig mode.

## 8. Phase 1 offline audit (2026-11-19)
Audited on `codex-dev` at `f37bf91` after fetching `origin/main`, `origin/claude-dev` and `origin/codex-dev`.
No application code or Supabase configuration was changed, and no device tests were run. The current implementation
and proposed next steps are documented in the Offline section of `docs/architecture.md` and in the Phase 1 entry in
`docs/roadmap.md`.

- The web app implements its own cache and queue in `app/index.html`; it does not use `core/src/offlineQueue.ts`.
  Previously opened band data, setlists, songs, library, links and members are cached in `localStorage`. There is no
  complete-band preload. The service worker keeps the app shell and CDN library available after a successful online
  installation, but does not cache Supabase requests.
- The current offline chip relies on `navigator.onLine`, so it can say online when Supabase cannot be reached; it is
  hidden when there is no local `user`. Reconnect attempts queue flush but do not guarantee refreshing cached reads
  when there was no queued change. Some management actions and all server lookups require connectivity.
- Startup has a provisional fast path: it reads a saved Supabase user id and draws cached data while auth initializes.
  This is not current server authentication. If initialization yields no session, the app can hide the cache. Offline
  access after a server revocation cannot be prevented until the device reconnects; do not describe cached access as
  authenticated or server-confirmed.
- The queue is persisted in `localStorage`, but storage write errors are swallowed and malformed queue JSON resets
  in-memory queue state. Conflicts have Use mine / Keep theirs; other failed queue items can be dismissed but have no
  retry action. Treat durable queue retention as unverified.
- Main and Claude docs are newer than this Codex handoff. Their current `app/index.html` also has lyrics/progression
  “Use” actions that save immediately; the Codex branch version audited here still requires the normal Save action.
  Do not import those unrelated UI changes as part of Phase 1 without separate scope approval.

### Phase 1 scope recorded by the audit
The audit proposed separate connectivity/authentication state, clear offline and pending-sync status, explanations for
server-only actions, cached viewing during offline auth initialization, and careful recovery after reconnect. Stage 1 was
subsequently approved and implemented below. Stage 2 and Stage 3 remain to be approved. Keep Supabase auth configuration,
SQL, database/Edge Functions, IndexedDB, queue redesign and new authentication mechanisms out of scope unless separately
authorized. Test on desktop browsers and actual iOS/Android devices before claiming PWA/offline behavior is verified.

### Stage 1 implementation status (2026-11-19)
Stage 1 is implemented on Codex `codex-dev` (not merged or deployed). `app/offline-state.mjs` contains the pure
four-state reducer; `app/index.html` records browser events, Supabase fetch outcomes, cache reads/scans and remote
`getUser()` confirmation. Auth remains unknown when an offline check cannot complete. Locally queued edits and view
preferences do not sync until the online identity check confirms the same user. The service worker precaches the new
module and uses cache version 2 so installed app copies can obtain it.

Reducer tests are in `test/offline-state.test.mjs`. The environment's shell has no `node` executable, but the 10-case
suite passed in the embedded Node test runner and the app module passed a syntax parse. No browser, Supabase project or
real device was available for integration tests.
Next task is Stage 2: a clear offline/pending-sync experience and explanatory behavior for actions requiring Supabase.

## Phase 2A.1 durable queue implementation (2026-11-20)
Implemented on `codex-dev` after fast-forwarding to `origin/codex-dev` at `1cc76c7`. The application now opens
`setlists-offline-queue` IndexedDB version 1, with `operations` and `metadata` stores. New operation batches are
validated and transactionally stored before entering the active sync queue. The existing localStorage queue and issue
keys are retained and still loaded; this stage does not migrate or delete their existing contents. New operations are
mirrored there when possible, and IndexedDB acknowledgement/resolution receipts prevent stale mirrored operations from
replaying after server completion or an explicit issue resolution. Cached app data remains in localStorage.

The UI reports saving, saved locally/waiting to sync, or a local persistence failure with a retry action. Failed
IndexedDB writes remain visible as unsaved drafts only in the open page; they are not sent, and closing the page loses
those drafts. Existing conflict detection and the Phase 1 authenticated-access gate remain in use. Service-worker cache
version 3 precaches the new queue module.

Automated tests use Node's built-in runner and an in-memory IndexedDB test double. Queue and Phase 1 state tests pass;
the inline app module and queue module pass syntax checks. `core`'s Vitest suite could not run because Vitest is not
installed, and dependencies were not installed. No browser, Supabase or real-device testing was performed. At the time,
legacy migration and sync acknowledgement recovery were follow-up work; migration is implemented in the Phase 2A.2
section below. Cached app-data migration remains Phase 2C.

## Phase 2A.2 migration and recovery implementation (2026-11-20)
Implemented on `codex-dev`, based on Phase 2A.1 commit `a5b83ffd5ce222b287ed593aabd78fca3de54cca`. IndexedDB is now
version 2, adding `issues` and `quarantine` stores. On queue load, the app reads the existing `q:<user id>` operation
array and `qi:<user id>` issue array, validates each record, and imports valid entries in source order. The source keys
are retained; `saveQ()` preserves their records and only appends unseen IDs. Acknowledgement/resolution receipts prevent
retained completed operations from being re-imported.

Migration uses transactional, repeatable writes and a `verifying` then `complete` metadata marker. Operations, issues and
quarantined malformed/divergent entries are reread before completion is recorded. A retry after an aborted migration
can safely resume from retained localStorage. IndexedDB wins for a same-ID payload mismatch; the localStorage copy is
quarantined and reported. Malformed records are quarantined, and operation/issue ID overlap is held as blocked so an
already rejected item is not resent.

If IndexedDB cannot open/read, migration verification fails, or stored queue data is malformed, the UI warns that saved
changes are inaccessible, exposes a queue-read retry, and blocks queue synchronization until recovery succeeds. The
Phase 1 authentication gate and existing song conflict handling remain in place. Service-worker cache version is 4.

Tests: Node's built-in runner passed the queue and Phase 1 suites (31 cases at implementation time). Coverage includes
valid operations/issues, duplicate/repeat migration, interrupted writes, malformed data, source-array retention,
IndexedDB precedence, account ID collisions, open/read failures and completion verification. The tests use the existing
in-memory IndexedDB test double; browser-native IndexedDB, multiple tabs, PWA/device restart and live Supabase behavior
were not tested. No dependencies were installed. Existing localStorage source records are retained and can grow over
time; quarantine has no record-editor UI. Lost Supabase responses can still cause duplicate submissions because
server-side idempotency is outside this phase. Phase 2C cache migration remains separate.

## Phase 2A.2 correction follow-up
The follow-up on `codex-dev` preserves source order within IndexedDB and legacy localStorage while interleaving by valid
timestamps. Equal or missing timestamps use a deterministic legacy-first fallback; known song, setlist-song and link
creation dependencies take precedence, and the Sync dialog reports fallback decisions. Divergent duplicate legacy IDs
retain the first FIFO occurrence only when there is no existing IndexedDB authority; later variants are stored and
verified in quarantine. Ownership metadata is validated before user filtering, so malformed ownership pauses queue load.
Tests cover interleaving, a cross-source dependency, missing timestamps, duplicate variants and malformed ownership.
Native IndexedDB and real-device behavior remain unverified. Phase 2A.3 follows in the implementation status below.

## Phase 2A.3 reliable synchronization implementation (2026-11-21)
Implemented on `codex-dev` after verifying the Phase 2A.2 correction commit and fetching `origin`. The durable queue
remains FIFO; startup and lock acquisition recover interrupted `inFlight` rows, and only one tab syncs per user at a
time using Web Locks, with a renewable expiring IndexedDB lease fallback. BroadcastChannel reports active sync and
queue changes between tabs. Retryable network, rate-limit and service failures use exponential backoff with jitter;
authentication failures pause for re-confirmation, while conflicts, permissions and validation failures stay visible.

Every operation type now uses `public.apply_offline_operation` from `sql/schema_v14_offline_operation_idempotency.sql`.
The invoker-security RPC applies changes through the caller's existing RLS and records user-scoped receipts in the
same transaction. Repeating the same operation ID and payload returns the prior outcome; a changed payload under the
same ID is rejected. Song edits retain field-level base/current conflict handling, including Spotify and Moises URL fields.
Run schema v14 after v12/v13 and before the updated
app is served; service-worker cache version is 5.

The queue and offline-state suites passed (41 tests) and the inline app module parsed. `test/offline-idempotency.sql`
provides a rollback-only Supabase integration check, but no PostgreSQL/Supabase runtime was available, so that test was
not run. The migration is not applied to the live Supabase project; do not treat server idempotency as validated or
deployed. Browser-native IndexedDB, multi-tab Web Locks, reconnect/crash recovery and real-device/PWA updates remain
untested. No dependencies were installed. Phase 2B has not started.

## v14 migration static-check correction (2026-11-21)
The empty song-edit field set is checked with `v_set = '{}'::jsonb` after validating that `v_set` is an object. The
unsupported `jsonb_object_length` call has been removed. `test/offline-idempotency-migration.test.mjs` statically checks
the object validation, empty-object comparison and absence of `jsonb_object_length`/`json_object_length`. The migration
was not applied to Supabase; the rollback-only integration test still requires a non-production Supabase project.

Google and Apple sign-in, how to rank "well known" song versions, pruning of removed songs and old history, how long
to keep history on the device, whether a progression link gets its own field beside the manual chords and bass line, and how to make the progression suggestions land on the right song, and what counts as the "most popular" version for the automatic YouTube and Spotify find, and whether other roles also want the Time signature in gig mode.
