# Architecture notes

Decisions so far are marked **Decided**. Everything else is a recommendation to confirm.
Last updated: November 2026. This version keeps the earlier reasoning and adds what was built since.

## Product decisions
- **Decided:** the app is offered to band members as a PWA (installable web app). PWA first was chosen after device
  testing. Expo (React Native) is parked.
- **Decided:** Supabase for the backend (Postgres, row-level security, sign-in).
- **Decided:** the app is free and never commercial.
- **Decided:** devices are iPhone, Android and tablets, so the layout must work on phones and tablets.
- **Decided:** the chords section lets members add links to sheet music or tabs.
- **Decided:** each song has a lyrics link (to a lyrics site the band already uses, for example Ultimate Guitar). An
  optional text box for the band's own lyrics or cues is wanted later.
- **Decided:** sharing arrived early so it can be tested with bandmates.
- **Decided:** a user can belong to several bands. Each band has several setlists (one per gig or arrangement).
- **Decided:** every change to a song is recorded. Who can edit depends on the access level (see Access control).
- **Decided:** offline use matters (venue Wi-Fi is unreliable). Reading offline and editing offline are both built.
- **Decided:** songs belong to the band, so a change to a song applies in every setlist.
- Original tempo and key are filled in from a song catalog, with a version picker when a song has several
  well-known versions (for example Walk This Way: Aerosmith or Run-DMC). The band can then edit them.
  Lookup is a convenience, not the core feature.

## System at a glance
```
Band member's phone, tablet or laptop (browser, or installed from the home screen)
  index.html      the whole interface and its logic, in one file
  config.js       Supabase project URL and publishable key
  sw.js           service worker: keeps an offline copy of the app
  localStorage    saved copies of bands, setlists, songs and links; the queue of changes waiting to sync
        |  HTTPS
        v
Supabase project
  Auth            email and password, emailed codes (sign-up, sign-in, reset)
  Postgres        tables, row-level security, functions and triggers
  Edge Function   lookup-song  ->  GetSongBPM API (key held as a secret), then Song Finder as the backup
  Realtime        enabled for song and setlist tables, not used by the app yet

GitHub Pages serves the app files from docs/setlist-pwa-v2/.
An email service (SMTP) sends the sign-in, sign-up and reset emails.
```

| Component | What it is | Notes |
| --- | --- | --- |
| Client app | One `index.html` module (interface, logic, metronome), `config.js`, `sw.js`, a manifest and three icons | Loads supabase-js version 2 from the jsDelivr CDN. The earlier `core/` library is not used yet. |
| Hosting | GitHub Pages, from `docs/setlist-pwa-v2/` | Everything in `docs/` is public. Keep SQL files and secrets out of it. |
| Database and auth | One Supabase project | The browser uses only the publishable key. |
| Edge Function `lookup-song` | TypeScript on Deno; checks the caller is signed in, then asks GetSongBPM (when its key is set) and falls back to Song Finder | Optional secret `GETSONGBPM_API_KEY`. Verify JWT is off because the function checks sign-in itself. |
| GetSongBPM | Tempo, key and time signature | Needs an API key on each request and a visible link back. Key requested, not yet received. |
| Song Finder (songfinder.dev) | Tempo, key and a second tempo reading, no key needed | Free, new (first release August 2026), rate-limited per address (about one call every one to five seconds), uneven coverage for less-known songs. Needs a descriptive User-Agent. Terms of use not reviewed. |
| Email service | Any SMTP provider connected in Supabase | The built-in sender only reaches team members and allows about 2 emails an hour. |

## Data model
Earlier concept:
```
User ──< Membership >── Band ──< Setlist ──< Entry
                                  Setlist ──< Change   (append-only history)
```
As built, songs belong to the band and a setlist only places them:
```
Band ──< Song ──< SongLink
Band ──< Setlist ──< SetlistSong >── Song
Band ──< Membership (access level, instrument roles) >── Profile
Band ──< Invite
Band ──< ChangeLog   (filled by a database trigger)
```

| Table | Purpose and key fields |
| --- | --- |
| profiles | One row per user: display name. Created automatically at sign-up. |
| bands | name, theme (band colour), logo (a small validated image stored as text), created_by |
| band_members | role is the access level (owner, admin, editor, viewer); roles is the list of instrument roles; last_setlist_id remembers the last-used setlist. A theme field remains from an earlier design and is unused. |
| band_invites | An 8-character code, the access level it grants (editor or viewer), expiry (7 days). Reusable until it expires. |
| songs | title, artist, version_label, bpm, musical_key, time_signature, chords, root_notes, notes, lyrics_url, youtube_url, catalog_ref, change_note, deleted_at |
| song_links | Labelled links on a song (sheet music, tab, lyrics, video, other). This is the earlier `charts` list. |
| setlists | name, gig_date, venue, notes, deleted_at. Gig date, venue and notes are not shown yet. |
| setlist_songs | A song's place in a setlist. position is a decimal number, so reordering does not rewrite every row. Override columns exist but are unused. |
| change_log | Every insert, update and delete on songs, links, setlists and setlist songs: who, when, old and new values, optional reason |

Design choices:
- Every row has a unique id the app can create itself, plus updated_at and deleted_at. Offline changes depend on this.
- Songs, links and setlists are soft-deleted. Hard deletes are limited to admins; the app uses them only when an owner deletes a whole band.
- Setlist songs and links point at their song and setlist together with the band, so data cannot cross between bands.
- Catalog `original` values and the "Original versus Changed for your band" display from the earlier design are not built yet.

## Privacy: who can see what
A band's data must only reach its members, and that is enforced **on the server**, not in the app.
- Every read and write is checked by row-level security against the person's membership of the band.
- The app only asks for bands the user belongs to, but nothing relies on that.
- Joining is by invite code typed in by the new person, created by an owner or admin. Removing a member revokes access immediately.

## Access control
Hiding a button in the app is a convenience. The database enforces all of this.

| | Owner | Admin | Editor | Viewer |
| --- | --- | --- | --- | --- |
| Read songs, setlists, links, history, members | Yes | Yes | Yes | Yes |
| Add and edit songs, setlists and links (including soft delete) | Yes | Yes | Yes | No |
| Create and list invite codes | Yes | Yes | No | No |
| Change access levels, remove members | Yes | Yes | No | No |
| Rename the band, set its colour and logo | Yes | Yes | No | No |
| Hard-delete rows | Yes | Yes | No | No |
| Delete the band | Yes | No | No | No |
| Transfer ownership | Yes | No | No | No |

A band has exactly one owner, who cannot be removed, demoted or leave. People can edit only their own instrument roles
and last-used setlist. Joining, changing a level, removing and transferring go through database functions, never direct edits.
Instrument roles (singer, guitarist, bassist, drummer, keyboards) are separate and only change what gig mode puts first.

## Versioning (change history)
- The earlier design was an append-only list of `Change` records with an inverse for each, and a restore that applies the
  inverse as a new change. The web app records history with a database trigger instead: every change stores the old and
  new row, who made it, when, and an optional reason.
- **Not built yet:** the Restore button. When built, a restore will be recorded as a new change, so nothing is rewritten.
- Edits are field-level. Two members changing different fields of one song never conflict.
- **Changed from the earlier design:** if two people change the same field (one of them offline), the later sync does
  not silently win. The person syncing sees both values and chooses Use mine or Keep theirs, and the history records
  which. The earlier rule was "the later one wins and both stay in history". If you prefer that, it is a small change.
- Per-change author and time give the "last changed by" information.

## Offline
- Reading: bands, setlists, songs, links and members you have opened are saved on the device and shown without signal.
- Editing (built, not yet on the site): changes to songs, setlist order, links and the song list are shown at once, saved
  on the device in a queue, and sent oldest first when a connection is available. They are retried when the device comes
  back online, when the app is opened again, and every 20 seconds while changes wait.
- Each new song, setlist entry and link is created with an id made on the device, so sending the same change twice does
  nothing the second time.
- A song edit sends only the fields that changed, together with the values they had. At sync time the app reads the song
  from the server, applies the fields nobody else touched, and shows any field someone else changed in the meantime.
  If the song changes while the app is merging, it reads again and retries.
- A lost connection stops the queue and keeps the order. A change the server refuses (for example, the person is now a
  viewer, or the song was deleted by someone else) does not block the rest: it moves to a "Check sync" list with the
  reason, and can be dismissed. The earlier design said to stop at the first failure; this is different so one bad
  change cannot block everything behind it.
- While changes are waiting, the screen shows the device's own copy. When everything has synced it refreshes from the
  server, but not while someone is typing in a song.
- The header shows "Offline", "N waiting" or "Check sync". Signing out with unsynced changes asks first, and the queue
  stays on the device for that person's next sign-in.
- Online only for now: creating, renaming, duplicating and deleting setlists, band settings, members and invites.
- Open: how long to keep history on the device.

## Lyrics and links
- Each song has a lyrics link. A text box for the band's own lyrics or cues is wanted later. The app never supplies or fetches lyrics.
- Links are accepted only if they start with http or https. The earlier `cleanLink` rule (unwrap pasted Google redirect
  links, strip tracking parameters) is not applied in the web app yet.
- Lyrics are copyrighted. Text a band pastes is stored on the server and shared with that band, so keep it members-only
  (row-level security), with no public pages and no bulk import. For a free, non-commercial band tool the risk is lower
  but not zero. If this grows, consider a licensed lyrics provider (check current terms). This is not legal advice.
- Sheet music and tabs: each song has any number of labelled links (`song_links`). Any editor can add or remove them.
  A link added without a label is currently stored without one; using the site name as the label is on the list.
- All of these fields are tracked by the change history like any other edit.

## Layout: phones and tablets
- Phone: one column. This is what the web app does at every width today.
- Tablet (about 768 px wide and up): two panes, setlist on the left and the selected song on the right. **Not built yet.**
- Gig mode is the stage view: large BPM and key, the next song, and panels chosen by instrument role.
- Test landscape and large text on a tablet.

## Metronome
- A JS timer is not accurate enough for a click. The web app schedules each click on the audio clock a short time
  ahead (a 25 ms timer looks 150 ms ahead), so timer jitter does not move the beat. This is the same idea as the
  `BeatScheduler` in `core/`.
- iPhone audio: with the ring/silent switch on, a plain web audio click is muted. The app sets the audio session to
  playback, loops a silent audio element, and resumes the audio on every tap and when the page becomes visible again.
- A screen wake lock keeps the screen on, in gig mode and while the metronome runs.
- Flash is an option for drummers who cannot hear the click. The full-screen flash is limited to three per second or
  fewer: every beat up to 180 BPM, beat 1 only above that, and no flash at all if even beat 1 would be too fast (for
  example a 1/4 bar at 300 BPM). The small beat dot in the metronome bar still follows every beat. The first time Flash
  is switched on, the app asks for confirmation with a photosensitivity warning. This is built and tested for every
  tempo and time signature, but not yet on the site.

## Catalog lookup (original key and tempo)
Server-side only (a Supabase Edge Function). The earlier plan, still the target:
1. Find the song and its well-known versions with MusicBrainz. Free for non-commercial use, one request per second,
   needs a descriptive User-Agent, core data is CC0. It has no tempo or key.
2. Get tempo, key and time signature for each version from GetSongBPM. Free API key, but a visible link back to
   GetSongBPM is required.
3. Merge into a confidence level: two sources agree = high, one source = medium, conflict = "check".
   Flag half-time ambiguity (for example 85 or 170 BPM).
4. The band's own values are stored separately and always win ("Original" vs "Changed for your band").

**Built so far:** the Edge Function tries GetSongBPM when its key is set, and otherwise (or when GetSongBPM has no match
or errors) uses Song Finder: it searches by title and artist and reads tempo and key for up to three distinct
recordings, spaced to respect the rate limit. With a title alone it lists matches by different artists. Each match
shows its source and a confidence level: high when Song Finder's two readings agree, medium for a single source, and
check when they disagree by more than 3 BPM (usually half or double time), with the second reading shown. Answers are
kept for ten minutes. The person picks a match, the values fill the song form, and nothing is saved until they save.
Not built: MusicBrainz, merging two sources into one result, a stored cache table, and the original-versus-changed
display.

Not usable: Spotify audio features (closed to new apps since 27 Nov 2024) and AcousticBrainz (frozen since 2022).
Chords stay manual. Later options: band corrections, and analysing a band's own recording with Essentia.

Providers sit behind a small interface so one can be swapped if its terms change. Check each provider's terms on
caching before storing results. Source accuracy varies, so values should be checked against the recording.
YouTube links start as a search for the chosen version and can be replaced with a specific video.

## Sign-in and email
- Email and password, with password reset by an emailed 6-digit code entered in the app, an email sign-in code for people
  who forget the password, sign-up confirmation by code, and change password from the menu.
- Codes are used instead of links because a link opens in Safari, not the installed iPhone app.
- Needs a custom email service (SMTP) in Supabase and three edited email templates. Confirm email is switched on last.
- Google and Apple sign-in are not built (Google is on the roadmap; test it in the installed iPhone app first).

## PWA notes (iPhone)
Findings from testing on real devices are marked.
- No automatic install prompt on iOS: users add the app to the Home Screen by hand (Share, then Add to Home Screen, from
  Safari only). **Found in testing:** this is easy to miss; an in-app install guide is on the roadmap.
- Web Push only works for installed apps.
- Sound only plays after a tap (fine: the metronome has a Start button). **Found in testing:** the click was silent in
  the browser with the silent switch on until the audio fix described above.
- Screen wake lock works on recent iOS. The click may stop if the screen locks, so use wake lock on stage.
- Installed apps have more stable storage. Shared data lives in Supabase, so a cleared cache costs a re-download, but any
  changes still waiting to sync would be lost, which is why the sync status is shown.
- Links may not open an installed PWA, so invites work by typing a code.

## Backend options (Supabase chosen)
| Option | Good for | Watch out for |
|---|---|---|
| Supabase (Postgres, row-level security, realtime) | Clear membership rules in SQL, easy history queries | You write the sync glue (now built as the queue above) |
| Firebase (Firestore, security rules, offline cache) | Built-in offline cache and realtime | Rules language is separate; history and ordering take care |
| Own API (e.g. on AWS) | Full control, fits multi-cloud experience | Most work to build and run |

## Database files and the order to run them
Run each file once, in order, in the Supabase SQL Editor as a new query. Later files are safe to run again.
These are not Edge Functions. Keep them in `sql/`, outside the public `docs/` folder.

| File | Adds |
| --- | --- |
| v1 | Core tables, access rules, history, create and join band |
| v2 | Reason field on song changes and in the history |
| v3 | Instrument roles and root notes |
| v4 | Access levels, band colour, invites with a level, member management, ownership transfer |
| v5 | Last-used setlist per member |
| v6 | Cleans up a deleted band's history |
| v7 | Band logo |
| check_schema | A read-only checklist of which updates are present |

The `lookup-song` Edge Function is deployed separately under Edge Functions and only needs redeploying when its file changes.

## Security notes
- The publishable key in `config.js` is meant to be public. The secret or service-role key must never be in the app or repository.
- The GetSongBPM key lives only as an Edge Function secret. Song Finder needs no key.
- All text from the database is escaped before display, links are accepted only if they start with http or https, and
  the band logo is checked again before it is shown.
- Emails contain codes, not links, and codes expire. Passwords must be at least 8 characters.

## Testing so far
Database changes were tested on a local PostgreSQL 16 with a stand-in for Supabase's auth layer: 97 permission checks
across owner, admin, editor, viewer and a non-member (with deliberately weakened rules to confirm the tests catch
mistakes), and separate checks for the last-used setlist, band deletion, the logo limits and the offline sync engine
(run against real row-level security). Screen logic was tested in Node with stand-ins. None of these tests are in the
repository yet and nothing re-runs them automatically. Confirmed on the live app by you: the iPhone test and the
delete-song update. `core/` has its own 23 tests.

## Running and changing it safely
1. For any change that includes SQL: run the SQL first, then upload the new `index.html`.
2. Upload `index.html` to `docs/setlist-pwa-v2/` and leave `config.js` alone.
3. Redeploy the Edge Function only when `lookup-song.ts` changes.
4. After a change, open the app in a private window to avoid a stale cached copy.
5. If something looks wrong, run `check_schema` to see which updates the database has.

## Known limitations and risks
- The whole interface is one large file, which will become harder to change.
- No automated tests are stored in the repository, and `core/` is not used by the web app.
- Offline editing is new and untested on real devices. Setlist, band and member changes still need a connection.
- A browser may clear saved data on a rarely used iPhone, losing changes that were still waiting.
- Email sign-in features depend on connecting an email service and editing three templates.
- Google sign-in is not built; sign-in could be lost on iPhone when redirected through Safari.
- Key and BPM lookup works without a GetSongBPM key through Song Finder, which is new, rate-limited and untested from the live site. Data is incomplete for some songs and can be half or double time.
- History cannot be restored with a button, and membership changes are not in the history.
- Invite codes can be reused until they expire.
- The home-screen icon is the same for every band.

## Open questions
1. ~~PWA first or Expo first.~~ Answered: PWA first.
2. ~~Sign-in method.~~ Answered for now: email and password plus emailed codes. Google (and Apple) still open.
3. Which versions to show for a song (how to rank "well known").
4. Do removed songs and old history ever get pruned?
5. Web address and hosting: stay on GitHub Pages, or buy a domain and possibly move hosting.
6. Same-field conflicts: ask the person (current) or let the later change win (earlier design).
7. How long to keep history on the device.
