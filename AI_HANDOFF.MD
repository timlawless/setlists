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
- **Database files:** v1 to v15 plus `check_schema`, run in order in the SQL Editor (listed in `docs/architecture.md`).
  v8 band link ending, v9 `invite_preview`, v10 `songs.song_structure`, v11 `song_views` (a person's guitar or bass view of a song), v12 `songs.spotify_url` and `songs.moises_url`, v13 allows the `backing` instrument role, v14 was made on the Codex branch for a better offline experience with cached information (details not seen), v15 `add_song_note` (reason-only notes).
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
5. Put the SQL files, `check_schema.sql` and the permission and sync tests into the repository (`sql/`). The v11 tests were run
   on an in-memory Postgres and are not stored yet.
6. Check the tighter progression searches on real songs (roadmap backlog 29, step 1 built). If they still miss, build step 2: a function that finds specific videos.
7. Decide whether a progression link needs its own field, then Google sign-in and history restore.
8. Listen links stage 2: a function (`find-listen-link`) that finds the most popular YouTube video and Spotify track for a song, with Use saving at once and the overwrite question, always overridable by hand. It needs a YouTube Data API key and a Spotify client ID and secret as Supabase secrets.
9. Check role-based gig mode on a real phone and tablet (sideways on a music stand), with each role and with two roles, and tune the order if the band wants it different. Do the same for the role-ordered Details view. Also check the Settings changes: that saving your own name works against the real database.
10. Confirm that a reason typed WITH a change shows in History on the real database (the History trigger may have lost the copy in a later SQL file), and find out why one save writes two History rows for the same song a fraction of a second apart. The three read-only queries are in the roadmap, item 15.
11. `docs/tester-guide.md` and `docs/go-live-checklist.md` still say instrument roles are chosen in the menu; update them when the current copies are available.
12. SQL v14 (Codex branch) is described by Tim as changes for a better offline experience, with cached information available without internet. Get its SQL file and the Codex `index.html`, describe v14 in `docs/architecture.md` and here, and check it does not clash with v15 (`add_song_note`). Both branches change the offline queue in `index.html` (this branch added a `note` item for reason-only notes), so compare the queue, `runOp`, `flush` and the cached-read code before merging into `main`.

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
Google and Apple sign-in, how to rank "well known" song versions, pruning of removed songs and old history, how long
to keep history on the device, whether a progression link gets its own field beside the manual chords and bass line, and how to make the progression suggestions land on the right song, and what counts as the "most popular" version for the automatic YouTube and Spotify find, and whether other roles also want the Time signature in gig mode.
