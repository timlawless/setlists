# Notes for AI coding agents and new contributors

## What this is
A free, non-commercial app for bands: setlists with tempo, key, chords, notes, lyrics and links, a metronome with an
optional flash, several setlists per band, several bands per user, change history, and offline use.
Used on iPhone, Android and tablets. Backend is Supabase. The target client is a PWA (PWA first or Expo first is
still open; see `docs/roadmap.md` step 2).

## Start here
1. Read `docs/architecture.md` (decisions and reasons) and `docs/roadmap.md` (what to do next).
2. Run `cd core && npm install && npm test && npm run typecheck`. All must pass before and after your change.
3. Tick off roadmap items and update the docs when a decision changes. Keep commits small, messages in the imperative.

## Rules that must not be broken
- **Lyrics.** Never add, fetch, scrape or generate song lyrics. The app only stores a link and text that band members
  type or paste themselves. Do not put lyrics in sample data, tests or docs.
- **Privacy.** A band's data is visible to its members only, enforced on the server with Supabase row-level security.
  Never rely on the client to hide data. Every policy needs a test that proves an outsider gets nothing.
- **Links.** Every stored URL goes through `cleanLink` (http and https only; unwraps Google redirect links; strips
  tracking). Never render a link that has not been cleaned.
- **History.** Every edit to a setlist is a `Change` with an author. Restores are new changes. Never rewrite history.
- **Ids** are random UUIDs, so devices never clash.
- **`core/` is platform-free.** No React, DOM or native APIs. Inject storage and clocks.
- **Tempo and key data is unreliable.** Show a confidence level; the band's own values always win.
- **Flash.** At most three flashes a second (`flashAllowed`).
- **Do not claim something works unless it was tested.** Device-specific behaviour (iPhone PWA audio, wake lock, offline)
  must be tested on real devices.

## The prototype
`prototype/Main.dc.html` is the UI reference, in a design-canvas format that needs a runtime not included here.
Read its `<script>` section for behaviour and data shapes (bands, setlists, entries, history). All data in it is sample data.

## Decisions so far
Supabase backend; free and never commercial; all members can edit; sharing not needed at first but wanted early for
testing; offline matters; tablets supported (two-pane layout).
