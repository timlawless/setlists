# Band setlist app

A free, non-commercial web app (PWA) for bands: setlists with tempo, key, chords, notes and links, a metronome with an
optional flash, a full-screen gig mode, several setlists per band, several bands per user, change history, and offline
use. It works on iPhone, Android, tablets and laptops, and can be installed from the browser.

Live app: https://timlawless.github.io/setlists/

## What it does today
- Sign in with email and password, or with an emailed code. Reset a forgotten password with an emailed code.
- Bands with four access levels: owner, admin, editor, viewer. Invite people with a typed code. Members see only their own bands.
- Songs belong to the band and are shared by its setlists. Each song has title, artist, artist version, time signature,
  BPM, key, chords, root notes, notes, a lyrics link, a YouTube link, and sheet music or tab links.
- Setlists: create, rename, duplicate, delete, reorder, search the band's songs, add and delete songs.
- Change history for every song: who, when, what changed, and an optional reason.
- Instrument roles (singer, guitarist, bassist, drummer, keyboards) that change what gig mode shows first.
- Metronome with click and an optional screen flash (limited to three flashes a second), tuned to work on iPhone.
- Works without signal: saved data can be read offline, and edits made offline sync when the connection returns.
- Band colour, logo and a short band link (for example `/#wc`) chosen by the owner or an admin. Light and dark mode.
- Key and BPM lookup through an Edge Function: GetSongBPM when its key is set, otherwise Song Finder (no key). With Song Finder you pick the right recording from a ranked list, then get its tempo and key. Each match shows its source and a confidence level.

## Layout
| Folder | What it is |
|---|---|
| `docs/` (top-level files) | The app: `index.html` (interface and logic), `config.js` (Supabase URL and publishable key), `sw.js`, manifest and icons. GitHub Pages publishes this folder, so the app is at the root address. `docs/setlist-pwa-v2/` holds only a redirect page for the old address. |
| `docs/architecture.md` | Decisions, data model, access control, offline, open questions. |
| `docs/roadmap.md` | What is done, what is waiting, what to do next, and the backlog. |
| `sql/` | Supabase SQL files, numbered in the order they are run. Add each new file here. |
| `core/` | TypeScript library with logic that must be right: change history, offline queue, metronome scheduler, link cleaner. Tested. Not used by the web app yet. |
| `prototype/` | Interactive UI prototype with sample data. A reference, not the live app. |
| `AGENTS.md` | Ground rules for AI coding agents and new contributors. |
| `AI_HANDOFF.MD` | A status snapshot for whoever picks the work up next. |

Everything in `docs/` is published on the web by GitHub Pages. Do not put secrets or SQL files there.

## Set it up
1. Create a Supabase project. In the SQL Editor, run the SQL files in order, each as a new query.
   `check_schema.sql` is a read-only checklist of which updates are present.
2. Deploy the Edge Function `lookup-song` (Edge Functions, deploy via the editor). Add the secret `GETSONGBPM_API_KEY`.
   Switch Verify JWT off for it: the function checks sign-in itself.
3. Connect an email service (Authentication, SMTP Settings) and paste in the three email templates (Authentication,
   Email Templates). Switch Confirm email on last.
4. Put the project URL and the publishable key in `docs/config.js`. Never use the secret or service-role key.
5. Enable GitHub Pages for the `docs/` folder.

## Changing it
Run any SQL first, then upload the new `index.html`. Leave `config.js` alone. Open the app in a private window to avoid a
stale copy. See `AGENTS.md` for the rules and `AI_HANDOFF.MD` for the current state.

## Run the tests
```bash
cd core
npm install
npm test          # 23 tests
npm run typecheck
```
The database and screen tests used during development are not in the repository yet; adding them is on the roadmap.

## Not built yet
Google sign-in, the iPhone install guide, the tablet two-pane layout, restore from history, the MusicBrainz and
merging of lookup sources, full lyrics text, and a per-band app icon. See `docs/roadmap.md`.
