# Development handoff

A status snapshot for whoever picks this work up next (a person or an AI). Last updated: November 2026, after the guitar or
bass view, the progression link finder and the Use-saves-at-once change.
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
- **Database files:** v1 to v11 plus `check_schema`, run in order in the SQL Editor (listed in `docs/architecture.md`).
  v8 band link ending, v9 `invite_preview`, v10 `songs.song_structure`, v11 `song_views` (a person's guitar or bass view of a song).
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
- **Progression link finder:** Find chords link / Find bass tab link lists search pages (Ultimate Guitar, Songsterr, Google).
  Open goes to a new page; Use (editors) puts the link in the box and saves it at once, after asking if something is already
  written there. Nothing is fetched. The lyrics finder behaves the same way: Use saves at once, with the same question.
- A box that holds just one link shows a larger Open button beside its label, "Chords: link" on song rows, and an Open
  button in gig mode.
- The GetSongBPM link was removed from the footer while no key is in use.

## 3. State of the work
`docs/roadmap.md`, "In progress and waiting", is the authoritative list of what is installed and what is awaiting review.
- **Tried by Tim and reported working:** the iPhone install test, and SQL v11 with the guitar or bass view.
- **Delivered, not yet confirmed on real devices:** Use saving at once and the larger Open button (lyrics and progression),
  the compact right-hand panel, Song structure (SQL v10), lyrics link suggestions (needs the `find-lyrics-link` function
  deployed and `GENIUS_ACCESS_TOKEN` saved), the progression link finder, and the earlier items listed in the roadmap
  (offline editing, flash limit, sign-in and invite changes, launch speed, install help).
- **Waiting:** the email service for reset and sign-in codes (SQL v7 needs it), the GetSongBPM API key, and a second lookup
  source for songs Song Finder cannot find.
- **Not built:** Google sign-in, history restore, MusicBrainz and merging lookup sources, full lyrics text, per-band app icon,
  high-contrast mode, a separate progression link field beside the manual chords and bass line, `cleanLink` on every stored link.

## 4. Next tasks, in order
1. Test the latest changes on real devices: the guitar or bass switch and Use in the right-hand panel and the phone layout,
   the overwrite question, the Open button size, gig mode, and the compact panel on a real desktop.
2. Help Tim finish the email setup and test reset and sign-in codes in the installed iPhone app.
3. Test offline editing on real devices (airplane mode, then a deliberate conflict from a second account).
4. Apply `cleanLink` to every stored link (a gap against `AGENTS.md`). The page already uses it for suggested links.
5. Put the SQL files, `check_schema.sql` and the permission and sync tests into the repository (`sql/`). The v11 tests were run
   on an in-memory Postgres and are not stored yet.
6. Decide whether a progression link needs its own field, then Google sign-in and history restore.

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
to keep history on the device, and whether a progression link gets its own field beside the manual chords and bass line.
