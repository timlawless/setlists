# Roadmap

Tick items off as they are done. Read `architecture.md` first: it records the decisions and the reasons.

Last updated: November 2026. This version replaces the earlier plan, which was written before the web app was built.
The earlier plan is kept below (steps 1 to 7) with the outcome of each step, so nothing from it is lost.

## Where things stand
- Free, never commercial. Devices: iPhone, Android, tablets. Backend: Supabase.
- **PWA first is decided and built.** The app is an installable web app served from `docs/` on GitHub Pages.
  The Expo (native) option is parked and can be revisited if a native feature is ever needed.
- Sharing is built and can be tested with bandmates: sign-in, invite codes, shared songs and setlists, shared history.
- The app has four access levels (owner, admin, editor, viewer) and instrument roles (singer, guitarist, bassist,
  drummer, keyboards) that change what gig mode puts first.
- The installed iPhone test was reported good. The main items in flight are the email setup for password reset and
  sign-in codes, and the live test of offline editing, the flash limit and the backup lookup (all built, not yet on the site).

## Done
- [x] Interactive prototype (`prototype/`): bands, several setlists per band, song editing and reordering, original
      key/tempo with a version picker, YouTube link, lyrics link and lyrics text, sheet music and tab links, change
      history with restore, offline demo, light and dark themes, metronome with sound and flash.
- [x] `core/`: change history, offline queue, metronome scheduler and flash rule, link cleaner, sheet music link list. 23 tests.
- [x] Architecture notes and decisions.
- [x] Repo on GitHub.
- [x] PWA test page and device tests (Android phone and tablet; iPhone browser and home-screen app).
- [x] Web app, built in these releases (each SQL file is run once, in order, in the Supabase SQL Editor):

| Release | What it added | SQL | Status |
| --- | --- | --- | --- |
| Test build v2 | Email and password sign-in, bands, invite codes, songs, setlists, change history, iOS audio fix | v1 | Done |
| Setlist screen | Song cards with title, artist, artist version, time signature, BPM, key, chords, notes, lyrics link, YouTube link, sheet music and tab links; reordering; metronome bar with flash; light and dark; offline reading | v1 | Done |
| Key and BPM lookup | Look up button, picker of matches, Edge Function `lookup-song` calling GetSongBPM | none | Built, waiting for the API key |
| Backup lookup source | The function falls back to Song Finder (no key needed) when there is no GetSongBPM key or it has no match; every match shows its source and a confidence level, with a warning when two readings disagree | none (redeploy the function) | Built, not yet on the site |
| Change history with reasons | History per song: who, when, what changed, optional reason | v2 | Done |
| Roles and gig mode | Instrument roles per band, full-screen gig mode with role-specific panels, root notes for bass | v3 | Done |
| Access levels | Owner, admin, editor, viewer; band members screen; invite codes with a level; remove, leave, transfer ownership | v4 | Done |
| Quality of life | Click button also stops the metronome; app reopens on the last-used setlist; no reload when returning to the tab | v5 | Done |
| Manage songs, setlists, bands | Song library with search and delete; delete song from its details; setlist rename, duplicate, delete; owner-only band delete | v6 | Done |
| Sign-in codes, reset, logo | Forgot password by emailed code, sign-in code, sign-up confirmation, change password, band logo | v7 | Built, waiting on email setup |
| Offline editing | Edits are saved on the device and sync when there is a connection; conflicts are shown for you to resolve; sync status in the header | none | Done (checklist passed) |
| Flash safety | The full-screen flash never exceeds three flashes a second, and asks for confirmation the first time it is switched on | none | Done (checklist passed) |
| Better song lookup | Song Finder results are a ranked list of recordings (exact title and your artist first, karaoke and tribute last) and you pick one to get its tempo and key | none (redeploy the function) | Built, not yet on the site |
| Band link | The owner or an admin chooses a link ending, for example `/#wc`, that opens the band | v8 | Built, not yet on the site |
| Metronome beat dots and sound rescue | Big beat dots (one per beat in the time signature, beat 1 green) in the metronome bar: in the empty middle on tablets and laptops, a row above the controls on phones while running; a safer sound start for iPhones (starts inside the tap, never waits forever, retries once, shows a warning if sound is blocked); the dots keep time from the phone's own timer when sound is blocked; the full-screen flash stays as an optional tick box | none | Built, not yet on the site; tested in headless Chromium with a real and a fake audio engine, not on a real iPhone |
| One pane or two, standing invite code, email choices | On a wide screen the setlist and song details are split 50/50, the details panel fills the window down to the metronome bar, and a button in the top bar switches to one pane (remembered on that device); Add song and Gig mode stay within the setlist's width; the invite code for each level stays the same until someone makes a new one, Share invite and Email invite show without making a code, and Email invite on a computer offers your email app, Gmail, Outlook or a copy of the message | none (codes are stored with an expiry 100 years away) | Built, not yet on the site; tested in headless Chromium and a simulated browser, not on a real email account |
| Accept-invitation page (phase 2) | An invitation link opens "Join [band]" with the access level, email, password, confirm password and an optional name, and one Accept invitation and join button; no code to type; an email that already has an account is moved to Sign in and joins after signing in; a wrong or expired link says so; the share message now leads with the link and keeps the code as a backup | v9 | Built, not yet on the site; tested in headless Chromium and on a real in-memory Postgres, not on a real phone or the real database |
| Faster launch on slow connections (step 2) | The offline helper (`sw.js`) still asks the network first so uploads show up, but if the network has not answered within one second it opens the saved copy at once and refreshes it in the background; a server error in the middle of an upload no longer overwrites the saved copy | none; `sw.js` changes | Built, not yet on the site; tested in headless Chromium against a server made slow, broken or offline, not on a real phone |
| Faster login and clearer sign-up (phase 1) | The sign-in and create boxes are a real form with one submit button, so the phone keyboard's Go key submits on every device (and password managers can offer to save); the create view has a coloured top band, its own welcome line, a Confirm password box and a Create my account button, clearly different from the plain sign-in view; at launch a saved sign-in shows a loading screen instead of the sign-in card, and the saved setlist is drawn at once from the copy kept on the device while the server is checked in the background | none | Built, not yet on the site; tested in headless Chromium with a real Enter key and a slow fake server, not on a real phone |
| UI cleanup 2: tablets and laptops | On screens 900 px wide or more the setlist sits on the left and the open song's details (with Save, Move up and Move down) on the right, which stays in view while the list scrolls; the first song is selected for you; text is a little larger; narrower screens keep the inline details and resizing across 900 px switches layouts by itself | none | Built, not yet on the site; tested in headless Chromium at 1366, 1280 and 1024 px wide plus 820 and 390 px, not on a real tablet |
| UI cleanup 1: small phones | One compact row per song (about 4 fit where 1.5 did), tap the title to open details, Move up and Move down inside the details; BPM and key shown first; 44 px buttons and boxes on touch screens; metronome bar slim when idle; band name replaces the band picker when there is one band; menu, members and add-song screens fill a phone and keep Close pinned at the top | none | Built, not yet on the site; tested in headless Chromium at four screen sizes, not on a real phone |
| Simpler welcome screen (build A) | First screen is two big choices (I am new / I already have an account); each shows only its own short form with plain help text; the invite code is a box on the create form so one tap makes the account and joins the band; forgot-password buttons sit behind Trouble signing in; returning people go straight to Sign in; numbered install steps fixed | none | Built, not yet on the site; tested in a simulated browser and in headless Chromium at four screen sizes, not on a real phone |
| Easier sign-up and invites | Join box on the "No bands yet" card; invite links ending `#join-CODE` that add the person after sign-up or sign-in; Copy invite link and Copy code only buttons; email typo check; show password; name required; clearer sign-in message; Enter key signs in and an unknown email is asked for a name; Share invite and Email invite buttons (they open your share sheet or mail app, the app sends no email itself) | none | Built, not yet on the site; tested only with a stand-in database |
| iPhone install help | An Install card on the first screen (iPhone: Share, Add to Home Screen, with a Copy link button for people stuck in WhatsApp's browser; Android: Install app button); Not now, and a menu button to bring it back; the invite code is shown for retyping in the installed app | none | Built, not yet on the site; tested only in a simulated browser |
| App at the site root | The app moves to the top of `docs/`, so https://timlawless.github.io/setlists/ opens it; the old address redirects | none | Built, not yet on the site |

## The earlier plan: what happened to each step
| Earlier step | Outcome |
| --- | --- |
| 1. PWA test page | Done. Android passed. The iPhone browser click was silent with the ring/silent switch on, fixed by switching the audio to the playback channel with a looping silent element. iPhone home-screen test reported good. |
| 2. Decide PWA first or Expo first | Done: PWA first. |
| 3. Supabase schema and members-only rules | Done (SQL v1 to v7). Row-level security enforces membership and access level. Permission tests (97 checks for access levels, plus others) were run on a local copy of the database; they are not in the repository yet. |
| 4. Milestone 1: solo app on the device | Replaced. The app went straight to a Supabase-backed version with a saved local copy for offline reading; editing offline is now built on top. The `core/` library is not used by the web app yet. |
| 5. Sharing for testing | Done: sign-in, invite codes (typed, or by invite link), shared history. Sync is done by a queue in the app (see `architecture.md`), not by `core/`. |
| 6. Catalog lookup | Partly done: GetSongBPM through an Edge Function with a link back on the site (waiting for the API key), plus Song Finder as a backup that needs no key. Each match shows its source and a confidence level. MusicBrainz versions, merging two sources into one result and the cache table are not built. |
| 7. Polish | Partly done: wake lock on stage, "Auto" theme following the phone, stage view (gig mode). Flash safety rule and first-time warning built. iPhone install help built, not yet on the site. Not done: high-contrast mode. |

## In progress and waiting
1. **GetSongBPM API key.** The documentation confirms a key is required, and a visible link back (done). The lookup no
   longer depends on it: without a key, the function uses Song Finder. Song Finder is new, rate-limited per address and
   covers less-known songs unevenly, so test it from your side and keep the GetSongBPM application going.
2. **Email sending.** Password reset, sign-in codes and sign-up confirmation need a custom email service in Supabase
   (the built-in sender only reaches team members and allows about 2 emails an hour). Then paste in the three email
   templates and, last, switch Confirm email on.
3. **Install the v7 update** (SQL v7 and the new page) and test reset, sign-in codes and the logo.
4. **Install the offline editing and flash safety update** (one `index.html`, no SQL) and test it with the connection switched off.
5. **Install the sign-up, invite and install-help update** (one `index.html`, no SQL) and run checklist sections B5 and B6 before the first band starts.

## Next up, in order
1. [x] **Flash safety.** Built: the full-screen flash is limited to three a second (every beat up to 180 BPM, beat 1
       only above that, and not at all if even that would be too fast), with a warning the first time Flash is switched
       on. Tested for every tempo and time signature. Still to do: upload it and try it on a device.
2. [ ] **Finish the sign-in setup** (item 2 above) and test it in the installed iPhone app.
3. [ ] **Test offline editing on real devices.** Airplane mode: edit a song, reorder, add and delete; reconnect; check
       the history, and create a deliberate conflict from a second account.
4. [x] **iPhone install guide in the app (built, not yet on the site).** There is no install button on iPhone; people must use Share, then Add to
       Home Screen, and it was hard to find during testing. Show a short guide with a picture.
5. [ ] **Tablet two-pane layout.** Setlist on the left, selected song on the right, from about 768 px wide.
       The earlier design asks for it; the web app is still one column.
6. [ ] **Google sign-in.** Needs a Google Cloud setup and a test in the installed iPhone app first.
7. [ ] **Catalog improvements.** MusicBrainz to list well-known versions, merging two sources into one confidence level,
       a cache table, and "Original" versus "Changed for your band" shown on each song.
8. [ ] **History restore.** A Restore button on a history entry, recorded as a new change.
9. [ ] **Housekeeping.** Keep the SQL files and the tests in the repository (`sql/` already exists), reuse `core/`
       where it fits (link cleaner, offline tests), and show an app version number in the menu.
       Also: apply `cleanLink` to every stored link, as `AGENTS.md` requires (the web app currently only checks for http
       and https).

## Later and ideas
Not committed. Move any of these up by saying so.
- Band logo on the app icon (the home-screen icon is fixed when the app is installed, so a per-band icon needs extra handling).
- Band links such as `#band-name`, once the web address is settled. Domain and hosting are undecided.
- High-contrast mode.
- Full lyrics text stored in the app, members only (the earlier prototype had a lyrics text box; the web app has a lyrics link only).
- Remember the last-used band across devices, as is done for setlists.
- Gig date and venue on setlists (the columns exist; nothing shows them yet).
- A printable or PDF setlist, and drag-and-drop reordering.
- Link cleaning on paste (unwrap Google redirect links, strip tracking), using the `cleanLink` rule from `core/`.
- Default label for a link (the site name) and adding a typed link on save.
- A setlist note shown large in gig mode.
- Membership changes (promotions, removals) in the history.
- Single-use invite codes and cancelling an unused code.
- Pruning of removed songs and old history (open question).

## Backlog: changes you want to make
Add a row for each change. Source says who suggested it. Priority is Now, Next or Later. Status is Idea, Planned, Built or Done.

| # | Change | Source | Notes | Priority | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Flash limit and first-time warning | Earlier design | Found when comparing the old notes with the app. | Now | Built |
| 2 | Band logo on the app icon | You | Optional, can wait. | Later | Planned |
| 3 | Google sign-in | You | Test in the installed iPhone app. | Next | Planned |
| 4 | Backup source for key and BPM lookup | Claude | Song Finder, used when there is no GetSongBPM key or no match. | Now | Built |
| 5 | Full lyrics text instead of a link | You | Said it may be added later. | Later | Idea |
| 6 | iPhone install guide | Earlier design | You could not find the install option. Built as an Install card; needs a test on real phones. | Now | Built |
| 7 | Tablet two-pane layout | Earlier design | Setlist left, song right. | Next | Planned |
| 8 | History restore | Earlier design | Recorded as a new change. | Later | Planned |
| 9 | App version number in the menu | Claude | Helps spot stale copies. | Next | Idea |
| 10 | Easier sign-up and invite for the first testers | You | Join box on the card, invite links, email typo check, Enter key, Share invite and Email invite buttons. Email stays off for the alpha. | Now | Built |
| 11 | App sends invite emails itself | You | Needs an email sending service, a verified sender address and an Edge Function. After the alpha. | Later | Planned |
| 12 | Simpler welcome screen for new testers (build A) | You | From watching testers: confused by which button, the boxes, the code step and installing. Build A covers the first three. | Now | Built |
| 13 | Install-first page on iPhone (build B) | You | A big step-by-step install screen before sign-up, with the Share icon drawn in and Continue in browser. Do after seeing build A with real people. | Next | Planned |
| 14 | UI cleanup 1: small phones | You | Compact song rows so more songs fit, 44 px tap targets, slimmer metronome bar, tidier top bar, full-screen dialogs. Needs a look on real phones. | Now | Built |
| 15 | UI cleanup 2: tablets and laptops | You | Use the width: setlist beside song details, larger text. The metronome stays in the full-width bar. Needs a look on a real tablet. | Now | Built |
| 16 | UI cleanup 3: gig mode and polish | You | Check gig mode at every size and sideways on a music stand. | Later | Planned |
| 17 | Metronome beat dots and sound rescue | Tester feedback | Drummer asked for big Soundbrenner-style dots; one iPhone tester heard and saw nothing. Needs a test on real iPhones. | Now | Built |
| 18 | Login and sign-up, phase 1 | You | From testers: Enter did not sign in on phones, launch looked like a new login, sign-up looked too like sign-in. Built; needs a test on real phones. | Now | Built |
| 19 | Accept-invitation page (phase 2) | You | A link opens "Join the band" with email and new password and one Accept button. Needs SQL v9 (invite_preview) so the page can show the band name before sign-in. Needs a test on real phones. | Now | Built |
| 20 | Launch speed, step 2 (sw.js) | You | After phase 1 the app still waited for GitHub to send the page before drawing anything. Now it waits at most one second. Needs a test on a real phone and a slow connection. | Now | Built |
| 21 | One pane option, 50/50 split, standing invite code, email choices | You | You found the two panes messy on a desktop; Add song drifted over the details; the invite code expired and Share and Email invite were hidden; Email invite did nothing. Built; needs a look on a real desktop and a real email account. | Now | Built |
| 22 | (add your next change here) |  |  |  |  |

## Decisions since the earlier plan
- **Songs belong to the band, not to a setlist.** A change to a song applies in every setlist. Per-setlist overrides
  were built and then removed at your request; their database columns remain but are unused.
- **Access levels replace admin and member:** owner, admin, editor, viewer. New people join as editors, or viewers if
  the invite says so. Editors can delete songs and setlists (kept in the history). Only the owner can delete the band
  or hand it on.
- **Instrument roles are separate from access levels** and are stored per band.
- **Band colour is a band setting** set by owners and admins. Light or dark mode stays personal.
- **Two people changing the same field offline is shown to the person syncing, who picks Use mine or Keep theirs.** The
  earlier design said the later change wins. This is different on purpose, so a change is never overwritten without
  anyone seeing it. If you prefer the earlier rule, it is a small change.
- **Emails carry codes, not links.** Links open in Safari rather than the installed iPhone app.
- **Lyrics stay a link for now.**
- **Declined for now:** tap tempo, a Deezer-based tempo backup, bulk song import.

## Notes for whoever picks this up
- Run `cd core && npm install && npm test` before and after changes to `core/`. Keep `core/` free of platform code.
- For any change that includes SQL: run the SQL first, then upload the new `index.html`. Upload to `docs/`
  and leave `config.js` alone. Open the app in a private window to avoid a stale copy.
- Lyrics: never ship or fetch lyrics. See "Lyrics and links" in `architecture.md`.
- Source accuracy for tempo and key varies. Show a confidence level and let the band's own values win.
- Open questions are listed at the bottom of `architecture.md`.
