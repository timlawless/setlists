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
- **Decided:** each song has an optional free-text Song structure (for example `V C V C M8 V C Outro`), shown in the
  song details only for now.
- **Decided:** the app can suggest a lyrics link for a song (a specific Genius page when one is found, otherwise search links). It only ever
  suggests links: it never fetches or copies lyrics, never saves a link unless the person taps Use (which saves it at once), and never replaces an
  existing link without asking.
- **Decided:** the Root notes box is removed from the app for now (song details, song rows, and the bass panel in gig mode). The
  `songs.root_notes` column stays in the database so existing values are kept and the box can be brought back later. The history
  still reads old Root notes changes correctly. A bass player's gig mode showed only the tempo and key tiles and the song notes while the box was gone; the box has since returned as the Bass line (see Guitar or bass view).
- **Decided:** the chord/progression box has a Guitar chords / Bass line switch. Which view shows is remembered per person and song, defaults to bass for bassists and guitar for everyone else, and anyone can switch on any song. A lookup suggests chord or bass tab links, to begin with only as links that open in a new page.
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
  localStorage    cached app data and legacy queue compatibility; IndexedDB holds new durable operations
        |  HTTPS
        v
Supabase project
  Auth            email and password, emailed codes (sign-up, sign-in, reset)
  Postgres        tables, row-level security, functions and triggers
  Edge Function   lookup-song  ->  GetSongBPM API (key held as a secret), then Song Finder as the backup
  Realtime        enabled for song and setlist tables, not used by the app yet

GitHub Pages deploys the contents of `app/`, so the app is at https://timlawless.github.io/setlists/.
An email service (SMTP) sends the sign-in, sign-up and reset emails.
```

| Component | What it is | Notes |
| --- | --- | --- |
| Client app | One `index.html` module (interface, logic, metronome), `config.js`, `sw.js`, a manifest and three icons | Loads supabase-js version 2 from the jsDelivr CDN. The earlier `core/` library is not used yet. |
| Hosting | GitHub Pages, from `app/` | Everything in `app/` is public. Keep SQL files and secrets out of it. |
| Database and auth | One Supabase project | The browser uses only the publishable key. |
| Edge Function `lookup-song` | TypeScript on Deno; checks the caller is signed in, then asks GetSongBPM (when its key is set) and falls back to Song Finder | Optional secret `GETSONGBPM_API_KEY`. Verify JWT is off because the function checks sign-in itself. |
| Edge Function `find-lyrics-link` | TypeScript on Deno; checks the caller is signed in, searches Genius for the song and returns up to three ranked links to Genius song pages (never lyrics text) | Secret `GENIUS_ACCESS_TOKEN` (a Genius client access token). Verify JWT is off because the function checks sign-in itself. Without the secret it answers with a note and the app falls back to its own search links. |
| GetSongBPM | Tempo, key and time signature | Needs an API key on each request and a visible link back. Key requested, not yet received. The link back was removed from the app footer while no key is in use; put it back before using a GetSongBPM key. |
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
Song ──< SongView >── Profile   (a person's last guitar or bass view of a song)
Band ──< Setlist ──< SetlistSong >── Song
Band ──< Membership (access level, instrument roles) >── Profile
Band ──< Invite
Band ──< ChangeLog   (filled by a database trigger)
```

| Table | Purpose and key fields |
| --- | --- |
| profiles | One row per user: display name. Created automatically at sign-up. |
| bands | name, theme (band colour), logo (a small validated image stored as text), slug (the band link ending), created_by |
| band_members | role is the access level (owner, admin, editor, viewer); roles is the list of instrument roles; last_setlist_id remembers the last-used setlist. A theme field remains from an earlier design and is unused. |
| band_invites | An 8-character code, the access level it grants (editor or viewer), and an expiry. The app makes standing codes with an expiry 100 years away, so a code is reusable until someone makes a new one (older codes made by the app expired after 7 days). |
| songs | title, artist, version_label, bpm, musical_key, time_signature, chords, root_notes (shown in the app as the Bass line), notes, song_structure (SQL v10), lyrics_url, youtube_url, catalog_ref, change_note, deleted_at |
| song_links | Labelled links on a song (sheet music, tab, lyrics, video, other). This is the earlier `charts` list. |
| song_views | One row per person per song (SQL v11): whether they last used the guitar or the bass view of the progression box. Private to that person, only for bands they belong to, removed with the song or band. |
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
- Reading: bands, setlists, songs, links and members you have opened are saved on the device and can be shown without signal.
- Editing (built in the web app): changes to songs, setlist order, links and the song list are shown at once, saved
  on the device in a queue, and sent oldest first when a connection is available. They are retried when the device comes
  back online, when the app is opened again, and every 20 seconds while changes wait.
- The implementation is in `app/index.html`; it does not use the separate `core/src/offlineQueue.ts` library. Cached
  records use `c:<user id>:...` in `localStorage`; legacy queued operations and issues remain at `q:<user id>` and
  `qi:<user id>`; new durable operations are in IndexedDB. Guitar/bass view choices waiting to sync use
  `vq:<user id>`. Only records fetched or opened on that device are cached; there is no complete-band download.
- Each new song, setlist entry and link is created with an id made on the device, so sending the same change twice does
  nothing the second time.
- A song edit sends only the fields that changed, together with the values they had. At sync time the app reads the song
  from the server, applies the fields nobody else touched, and shows any field someone else changed in the meantime.
  If the song changes while the app is merging, it reads again and retries.
- A lost connection stops the queue and keeps the order. A change the server refuses (for example, the person is now a
  viewer, or the song was deleted by someone else) does not block the rest: it moves to a "Check sync" list with the
  reason, and can be dismissed. Conflicts can be resolved with Use mine or Keep theirs; other failed items currently have
  no retry action. Legacy queue/issue source writes and cached view writes remain best-effort. Phase 2A.2 imports and
  quarantines malformed legacy queue data before synchronization; cached app-data writes remain localStorage-based and
  best-effort until Phase 2C.
- While changes are waiting, the screen shows the device's own copy. When everything has synced it refreshes from the
  server, but not while someone is typing in a song.
- The header shows "Offline", "N waiting" or "Check sync". Signing out with unsynced changes asks first, and the queue
  stays on the device for that person's next sign-in.
- Connectivity display uses `navigator.onLine` and its `online`/`offline` events; this reports browser network state, not
  whether Supabase is reachable. When connectivity returns the app attempts to flush the queue, but does not always
  refresh cached reads if there was no queued change.
- The service worker caches the app shell and CDN library, but Supabase Auth, database and Edge Function requests always
  require a connection. The manifest and service-worker scope are relative to the deployed app path. Cache names include
  that path, but `localStorage` is shared by production and preview paths on the same origin.
- Online only for now: creating, renaming, duplicating and deleting setlists, band settings, members and invites.
- Open: how long to keep history on the device.

### Offline audit findings (2026-11-19)
- A saved Supabase session is used for a provisional fast start: `savedUser()` reads a user id from local storage and
  `instantFromCache()` displays cached data before `INITIAL_SESSION` finishes. This is local cached access, not proof
  that Supabase still considers the session or membership valid. When the browser is offline and auth initialization
  returns no session, the app now retains that provisional cache view; an online auth rejection can still end the view.
- New sign-in, history, song lookup, external pages, and direct-only setlist, band, member and invite operations require
  a connection. Metronome timing, flash, appearance preferences and generation of local search URLs do not call Supabase.
- `navigator.onLine` can show online while the Supabase service is unavailable. The sync chip is also hidden when there
  is no local user, even if an offline cache exists.
- Stage 1 is implemented by `app/offline-state.mjs`, imported by `app/index.html`. Its reducer tracks browser
  connectivity, Supabase reachability, cached-data availability and authenticated access independently. Browser online
  events reset server reachability to unknown; offline means unavailable. The Supabase client's fetch wrapper records
  HTTP responses below 500 as reachable, 5xx and transport failures as unavailable. A stored cache scan and cache reads
  mark cached access; this state does not establish identity or permission.
- Authentication remains unknown while a restored local session is being checked. When online, `sb.auth.getUser()` must
  confirm the current user before state becomes authenticated. Offline auth failure leaves it unknown, and the existing
  queued song/setlist edits and guitar/bass view sync wait until that confirmation. Authenticated requests continue to
  be authorized by Supabase and row-level security. An online 4xx identity response marks the session unauthenticated;
  transport errors and 5xx responses leave it unknown.
- The state model does not redesign the existing sync indicator. Stage 2 proposals remain: improve the offline and
  pending-sync display; explain or disable direct-only actions while offline; handle recovery and refresh more clearly.
  Do not add a new auth system, PIN/biometrics, IndexedDB, a queue redesign or a new data architecture in these stages.
- A cached user's identity is discovered from that browser's Supabase auth storage so only that user's cache is scanned.
  If auth storage is cleared, the app does not guess which account's cached band data to expose. Cached data can remain
  visible on an unlocked device after server-side revocation until reconnection; it is never proof that access remains
  authorized.

### Durable offline operation queue (Phase 2A.1, 2026-11-20)
- The web app now opens IndexedDB database `setlists-offline-queue`, version 1. It creates an `operations` store keyed by
  `operationId`, with unique per-user sequence and per-user/status/sequence indexes, and a `metadata` store for the
  monotonic sequence counter plus acknowledgement and resolution receipts. The queue module is `app/offline-queue.mjs`; `app/sw.js`
  precaches it and uses cache version 3.
- Each operation record associates the existing operation payload and `qid` with a user ID, FIFO sequence, status,
  attempt count, creation time and last error. Current operation formats remain in use for song edits, new songs,
  setlist entry creation, positions, removals, song deletion and link additions/deletions. Song edits retain their
  changed fields and base values; device-generated IDs and setlist relationships are preserved.
- New operations enter the live sync queue only after an IndexedDB transaction commits. Batch enqueue allocates sequence
  values and writes all records in one transaction. A failed open, request or transaction rejects the enqueue. The UI
  displays “Saving on this device…”, then “Saved on this device · waiting to sync” only after commit, or “Couldn't save
  on this device” with Retry. Failed writes remain as clearly unsaved drafts in the current page only; they are not
  sent or represented as durable, and will be lost if the page closes before a successful retry.
- Existing `q:<user id>` and `qi:<user id>` localStorage data is not migrated or deleted. Existing queue entries remain
  readable and sync through the existing path. Phase 2A.2 imports legacy queue and issue records into IndexedDB while
  retaining their localStorage source records. IndexedDB operations are authoritative for duplicate IDs; differences are
  quarantined and surfaced. Cached app data remains in localStorage; cache migration is Phase 2C.
- IndexedDB operations transition through `pending`, `inFlight` and `blocked`. Startup returns interrupted `inFlight`
  operations to `pending`; transient sync failures do likewise. A successful server response is recorded as an
  acknowledgement and removes the IndexedDB operation in one transaction. Permanent failures remain as `blocked`
  records and reappear in the existing sync issues list. Existing field-level song conflict detection and resolution,
  FIFO sync, and the Phase 1 confirmed-authentication gate remain in place.
- These client receipts do not provide server idempotency. If Supabase applies a write but the response is lost, the
  client can retry the same operation. Existing operation behavior remains responsible for that case until a separate
  server-side idempotency stage is designed and approved. There is no multi-tab lease or cross-tab coordination yet.
- Existing localStorage queue entries are not made more durable by this stage; their prior best-effort storage behavior
  remains. Browser-native IndexedDB, PWA restart behavior, real-device behavior, and Supabase sync were not tested here.
  Unit tests use a small in-memory IndexedDB test double and cover the queue transaction contract, not browser IDB
  implementation details.

### Legacy queue migration and recovery (Phase 2A.2, 2026-11-20)
- The IndexedDB schema is now version 2. It adds `issues` and `quarantine` stores while preserving existing operation
  records and metadata. Legacy source keys remain `q:<user id>` (pending operations) and `qi:<user id>` (sync issues).
- At account queue load, both localStorage values are read and parsed independently. Valid operation and issue payloads
  are migrated with their original IDs, payloads and array order. Invalid JSON, non-array values, malformed records,
  duplicate-ID payload disagreements and cross-account ID collisions are retained in the IndexedDB quarantine store;
  the original localStorage data is never removed. A legacy issue overlapping a queued operation is represented as
  blocked so it is not accidentally resubmitted.
- Migration writes are transactional and idempotent. A `legacyMigration:<user id>` marker first records `verifying`;
  the app rereads and checks operations, issues and quarantined rows, then separately commits and rereads `complete`.
  Startup repeats migration from the retained source data, which also discovers late localStorage-only entries. If a
  write or verification is interrupted, original data remains and a later load can safely retry.
- IndexedDB wins for duplicate operation IDs. A differing legacy copy is quarantined and reported. If IndexedDB cannot
  open, be read, or contains malformed stored records, queue loading reports that saved changes are inaccessible and
  gates all Supabase queue synchronization. A retry control reruns queue recovery. Phase 1 authentication gating and
  field-level song conflict handling are unchanged.
- `saveQ()` now retains existing localStorage queue/issue entries and appends unseen IDs rather than clearing completed
  items. Acknowledgement and resolution receipts suppress those retained copies during future migration. This preserves
  migration sources but can grow localStorage over time; safe pruning needs a separate reviewed policy.
- Migration completion is quiet when there is nothing to recover. Recovered counts, malformed/conflicting record counts,
  and unreadable-queue failures are shown in the Sync dialog. Quarantine is retained for recovery but has no dedicated
  user-facing record editor yet.
- Tests run under Node's built-in runner with the repository's in-memory IndexedDB test double. Browser-native IndexedDB,
  service-worker update behavior, real-device restarts, multiple-tab races and live Supabase behavior remain unverified.
  Client acknowledgement still cannot prevent a duplicate server submission after an applied write loses its response;
  server-side idempotency remains outstanding and is excluded from this phase.

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

## Song structure
- Each song has an optional free-text Song structure, for example `V C V C M8 V C Outro`. It is stored in
  `songs.song_structure` (SQL v10: text, not null, empty by default), so existing songs simply have an empty value.
- There is no list of sections, no dropdown and no checking of the notation: whatever a member types is saved
  (with spaces trimmed from each end).
- It is edited in the song details (the inline row on a phone, the right-hand pane on a wide screen), between the
  Title to Key boxes and Chords. Viewers see it only when it has text, and cannot change it; editors always see the box.
- It is not shown in the song list rows, in the Create a new song box or in gig mode. Adding it to gig mode later is a
  small change.
- It follows the same path as every other song field: shown at once, saved on the device in the offline queue, merged
  field by field at sync time (a same-field conflict is shown for the person to resolve), and recorded in the history,
  where a change reads "structure edited".
- **Status:** prepared, not yet on the site, not tested. Run SQL v10 first, then upload `index.html`.

## Lyrics link suggestions
- A **Find lyrics link** button sits under the Lyrics link box in the song details (under **More** in the wide-screen panel; editors only). It also
  runs by itself after a key and BPM match is used, but only when the Lyrics link box is empty.
- The app asks the `find-lyrics-link` function for specific pages and always adds three search links of its own (Genius, Ultimate Guitar, Google),
  built in the browser, so something useful appears even offline or before the function is set up. A search link is labelled as a search page, not a specific song.
- The function searches Genius (`api.genius.com/search`) with the client access token, keeps only ordinary `https://genius.com/...` song pages, ranks them
  by exact title and the artist typed, ranks karaoke, tribute and translation pages out, drops pages whose lyrics state is not complete, and returns at
  most three, each marked exact, close or possible. Answers are kept in memory for ten minutes.
- The person reviews the result: **Open** shows the page in a new tab, **Use** fills the Lyrics link box and saves it at once (it runs the same save as Save changes, so any other edits typed in the panel are saved with it), and nothing is stored before then. If the
  box already holds a link, Use asks before replacing it (declining keeps the old one). **Remove** empties the box (Save changes then removes the link). The box
  can always be typed in by hand.
- Suggested addresses go through the `cleanLink` rule (http and https only, Google redirect links unwrapped, tracking removed), ported from `core/src/links.ts`
  into the page. It is applied to suggestions only. Applying it to every stored link is still on the housekeeping list.
- **Lyrics rule:** neither the function nor the page ever downloads a lyrics page or any lyrics text, not even to check a match. Only search metadata is read.
- **Status:** prepared, not yet on the site. The ranking was tested on sample Genius-style data and the page flow in headless Chromium against stand-ins; the live Genius
  answer has not been checked from here. The Genius API terms have been read by the owner: no link back or credit is needed, so the footer has none.

## Guitar or bass view and progression links
- The chord/progression area of the song details has a switch: Guitar chords or Bass line. Guitar edits `songs.chords`; bass edits `songs.root_notes` (the old Root notes column, so no new column). Both boxes stay in the page and one is hidden, so text typed but not yet saved is kept when switching, and Save changes saves both. Both are recorded in the history like any other field.
- Which view shows: the person's remembered choice for that song, otherwise bass if their instrument roles in that band include Bassist, otherwise guitar. Anyone, including viewers, can switch on any song. The same switch and panel appear in gig mode for guitarists, keyboards and bassists.
- Remembering: the choice is stored in `song_views` (SQL v11), one row per person per song, and also kept on the device (`c:<user>:views:<band>`). A change is written to the device first and sent in the background (`vq:<user>` holds choices still waiting). Offline, or before v11 has been run, it stays on the device and is sent later; opening a band picks up choices made on other devices. A choice that cannot ever be saved (the song or band is gone) is dropped.
- `song_views` access: a person reads, adds, changes and removes only their own rows, and only for bands they belong to (row-level security with `is_band_member`); the song and band must match; the view must be `guitar` or `bass`. It is not part of the change history.
- Find chords link / Find bass tab link (in the view you are on) lists search pages: Ultimate Guitar, Songsterr and Google, for chords or for bass tabs. Each has Open (new page) and, for people who can edit, Use. Use puts the link in the box for the current view, asks first if something is already written there (Cancel keeps it, OK replaces it), and saves it at once (it runs the same save as Save changes, so any other edits typed in the panel are saved with it). Every link goes through `cleanLink`. The app fetches nothing and never copies chords, bass lines or lyrics.
- A box that holds just one link shows a larger Open button beside its label (as does a saved lyrics link), "Chords: link" on song rows, and an Open chords or Open bass line button in gig mode.
- Planned: a separate link field beside the manual chords and bass line, so both can be kept.

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
or errors) uses Song Finder in two steps. Step 1 searches by title and artist and returns up to eight recordings,
ranked so the exact title and the artist you typed come first and karaoke, tribute and similar re-recordings come last,
with album and year shown. Step 2 runs when the person taps a recording: it reads that recording's tempo and key. This
keeps the person in charge of choosing the right recording and uses fewer calls against the rate limit. Each match shows
its source and a confidence level: high when Song Finder's two readings agree, medium for a single source, check when
they disagree by more than 3 BPM (usually half or double time), with the second reading shown. Answers are kept for ten
minutes. Nothing is saved until the person saves the song. Not built: MusicBrainz, merging two sources into one result,
a stored cache table, and the original-versus-changed display.

Not usable: Spotify audio features (closed to new apps since 27 Nov 2024) and AcousticBrainz (frozen since 2022).
Chords stay manual. Later options: band corrections, and analysing a band's own recording with Essentia.

Providers sit behind a small interface so one can be swapped if its terms change. Check each provider's terms on
caching before storing results. Source accuracy varies, so values should be checked against the recording.
YouTube links start as a search for the chosen version and can be replaced with a specific video.

## Band links
A band's owner or an admin can choose a short ending for the band (letters, numbers and hyphens, 2 to 30 characters, unique
across all bands, a few words reserved). The link is the app address followed by `#ending`, for example
`https://timlawless.github.io/setlists/#wc`. After sign-in the app opens that band if the person is a member. Switching
band updates the address, and a link to a band you are not in shows a message that reveals nothing about the band.
The ending is stored in `bands.slug`; only owners and admins can change it, and the database enforces the format and
uniqueness. The hash is read in the browser, so it works on GitHub Pages without any server routing.

## Sign-up and invite links
- The create-account form has an Invite code box (an invite link fills it in); the code is saved and joined by the same path as a link, so one tap makes the account and joins the band. Codes can also be typed into a box on the "No bands yet" card, or in the menu. Spaces are removed and letters are upper-cased before the code is checked.
- An invite link is the app address followed by `#join-` and the code. On load (and when the address changes) the app saves the code in the browser (`pendingInvite`), removes it from the address bar and shows a note on the sign-in page. After sign-in it calls `join_band` once, opens that band and clears the saved code. A code that fails is cleared too, so it cannot loop; one that failed only because the phone was offline is kept.
- `join-` followed by letters is never read as a band link ending, and the band link setting refuses endings that start with `join-`.
- Browser storage is separate for Safari and the installed iPhone app, so a code saved in Safari does not reach the installed app. That is why the typed box stays.
- Sign-up checks that the email looks valid, offers a fix for common domain typos (for example `gmial.com`), lower-cases it and requires a name. This matters because with email off a mistyped address cannot be recovered.
- The first screen is two big choices, I am new and I already have an account. Each opens the same set of fields in a different mode (create: name, email, password, invite code; sign in: email, password and a Trouble signing in link holding the forgot-password and email-code buttons). A device that has signed in before (`hadAccount` in browser storage), and anyone signing out, goes straight to the sign-in form; an invite link goes straight to the create form. Enter moves down the create form and the last box creates the account; in the sign-in form Enter in the password box signs in. Supabase gives the same reply for an unknown email and a wrong password, so the app cannot tell them apart: a failed sign-in shows a message that stays on screen, tells new people to tap I am new, and opens Trouble signing in.
- In Band members and access, **Share invite** opens the phone's share sheet (`navigator.share`) with a ready message, or copies the message where there is no share sheet. **Email invite** opens the person's own mail app through a `mailto:` link. The message holds the app address, iPhone install steps, the code and the invite link. The app sends no email itself; sending from the app needs an email service and is on the roadmap for after the alpha.

## Sign-in and email
- Email and password, with password reset by an emailed 6-digit code entered in the app, an email sign-in code for people
  who forget the password, sign-up confirmation by code, and change password from the menu.
- Codes are used instead of links because a link opens in Safari, not the installed iPhone app.
- Needs a custom email service (SMTP) in Supabase and three edited email templates. Confirm email is switched on last.
- Google and Apple sign-in are not built (Google is on the roadmap; test it in the installed iPhone app first).

## PWA notes (iPhone)
Findings from testing on real devices are marked.
- No automatic install prompt on iOS: users add the app to the Home Screen by hand (Share, then Add to Home Screen, from
  Safari only). **Found in testing:** this is easy to miss, so the app shows an Install card (see Install help below).
- Web Push only works for installed apps.
- Sound only plays after a tap (fine: the metronome has a Start button). **Found in testing:** the click was silent in
  the browser with the silent switch on until the audio fix described above.
- Screen wake lock works on recent iOS. The click may stop if the screen locks, so use wake lock on stage.
- Installed apps have more stable storage. Shared data lives in Supabase, so a cleared cache costs a re-download, but any
  changes still waiting to sync would be lost, which is why the sync status is shown.
- Links may not open an installed PWA, so invites work by typing a code.

## Invitation page (SQL v9)
- An invitation link is the app address plus `#join-CODE`. A signed-out visitor sees the invitation page: the same form as Create account, in a third mode (`invite`), with the title "Join [band]", the access level, email, password and confirm boxes, an optional name (shown after the password boxes; blank means the start of the email address) and one Accept invitation and join button. There is no code box: the code is saved in browser storage (`pendingInvite`) and the existing path joins the band as soon as the sign-in event arrives.
- The band name and level come from the database function `invite_preview(code)` (SQL v9), a security-definer function that anyone, signed in or not, may call. It returns one row only for a valid, unexpired code, and nothing for a wrong or expired one. It exposes no other data: the invites and bands tables stay private. Joining still needs sign-in and still goes through `join_band`. Codes are 8 hexadecimal characters and a standing code does not expire, so guessing one is not practical but a code that has been shared widely stays usable: make a new code if one gets out. Anyone holding a code can see the band name before joining.
- If the lookup fails (offline, or v9 not yet run), the page falls back to the normal create form with the code filled in. A wrong or expired code clears the saved code and shows the welcome screen with a message. If the email already has an account, the form switches to Sign in, keeps the invitation and says so; signing in then joins the band.
- The Share invite and Email invite message now leads with the link and keeps the code as a backup.
- Checked on Postgres 18 (PGlite) with both a text and an enum `role` column: valid, lower-case, padded, expired, wrong and empty codes; no direct access to the tables for anonymous visitors; safe to run twice.

## Service worker and launch speed (sw.js)
- App files (the page, `config.js`, the manifest, icons) are fetched network first so that an upload shows up quickly. If a saved copy exists and the network has not answered within `WAIT_MS` (one second), the saved copy is used at once and the network request carries on in the background and refreshes the saved copy (`e.waitUntil`). On a slow connection a new upload may therefore need one extra launch to appear.
- A failed answer (for example a 404 while an upload is half done) never replaces a saved copy: the saved copy is used instead. The old worker saved the error page over the good copy.
- With nothing saved yet (first visit, or an address with extra text after it such as `?check=1`) it waits for the network as before. Offline it opens the saved copy at once. The Supabase library from the CDN is still served from its own saved copy first. Data calls to Supabase always go to the network.
- If you change what the offline helper saves, bump `VERSION` so installed copies drop the old files.

## Sign-in form and fast start
- The sign-in and create boxes are one real `<form id="authForm">` with a single submit button (`#authGo`, labelled Create my account or Sign in by mode). Submitting calls `doSignUp` or `doSignIn`. Every other button inside the form is `type="button"`. This is what makes the phone keyboard's Go key work: phone keyboards often do not send a normal Enter key event, but they do submit a form. On a computer, Enter in an early create box moves to the next box instead. The keyboard hints (`enterkeyhint`) read Next on every box except the last.
- The create view (`#auth.new`) has a coloured top band and tinted background, its own welcome line, a Confirm password box (checked before the account is made) and the invite code box. The sign-in view is plain, with a Welcome back line and the Trouble signing in link.
- Launch: a tiny script in the page head adds `booting` to the page when Supabase has saved a sign-in on the device (a `sb-...-auth-token` key in browser storage). While `booting` the sign-in card is hidden and a "Loading your setlists…" card shows. Right after the page loads, the app reads the saved user from that same key (`savedUser`), treats them as signed in (`provisional`) and draws the saved copy of the bands, setlists and songs (`instantFromCache`, the same copies used for offline viewing). `booting` is removed by the first `render()`.
- When Supabase confirms the sign-in (`INITIAL_SESSION`), `loadBands` runs as usual to refresh from the server. If the data is unchanged and the person is typing, the screen is left alone (`quietRefresh`). If Supabase says there is no sign-in any more, the sign-in screen shows with "Your saved sign-in has expired."

## Standing invite code
- Each band has one standing invite code per access level (Editor, Viewer). Opening Band members and access (as an owner or admin) calls `ensureInvite`, which reads the band's invites for the chosen level, picks the newest one that is "standing" (an expiry more than 50 years away, or an expiry the app cannot parse) and shows it with Share invite, Email invite, Copy invite link and Copy code only. If there is none it makes one (expiry 100 years away; if the database refuses a long expiry it falls back to the usual 7 days and the screen says so). Old 7-day codes are not touched; they run out by themselves.
- Make a new code asks first, then deletes the band's invites for that level and makes a new standing one, so the old code stops working at once. Join and the invitation page treat a standing code like any other unexpired code, so no SQL change is needed (the v9 function was checked with a code that expires in 100 years).
- Email invite: a phone (a coarse pointer) opens its mail app directly (`mailto:`); a computer shows a chooser: My email app (`mailto:`), Gmail (compose link), Outlook (outlook.live.com compose link) or Copy message. Mail apps are often not set up on a computer, so a bare `mailto:` can do nothing.

## Tablet and laptop layout
- At 900 px wide or more (`wideQ`, a `matchMedia` query) and with two panes chosen (`body.dual`, below) the list column (`#left`: the Add song and Gig mode row, then the list) and the side pane sit in a 50/50 two-column grid (`#split`). The pane (`#pane`) shows the open song's details in an `article.pane` that carries the same `data-id` and `data-sid` as a list row, so the one click handler on `#split` serves both. The pane stays in view while the list scrolls (sticky) and scrolls by itself, stopping above the metronome bar. The metronome stays in the full-width bar; its dots already fill the middle of it.
- Wide screens always show one song: the first is chosen when nothing is open (also after a delete or a different setlist), and tapping the open row keeps it open. Under 900 px the details open inline in the row as before and the pane is hidden. Crossing 900 px (rotating a tablet, resizing a window) redraws by itself.
- The pane is as tall as the window down to the metronome bar (`height: calc(100vh - 76px - var(--barH) - 12px)`, where `--barH` is the bar's height kept up to date by a `ResizeObserver`, so the pane shortens when the bar grows while the click runs) and scrolls inside itself; the card inside fills the panel (`min-height: 100%`).
- A button in the top bar (`#paneBtn`, wide screens only) switches between two panes and one pane. The choice is saved on the device (`paneMode` in browser storage); in one pane the list is a single column and details open inside the row as on a phone. `dual()` is true only on a wide screen with two panes chosen.
- The right-hand panel uses a compact form of the song details (`detail(s, true)`) so a lightly filled song fits without scrolling: Song structure is one line, Chords sits beside Notes in two columns, those boxes start at one line and grow with their text (`textarea.grow`, resized by script), the buttons are smaller on mouse-and-keyboard screens (touch screens keep their 44 px targets), with Move up and Move down sized to their text, and the rarely used parts (reason for change, lyrics and YouTube links, sheet music and tab links) sit under a **More** section that is closed by default and stays open or closed when the panel is redrawn (`moreOpen`). The Save, Look up, History, Remove and Delete buttons stay visible. Phones and the one-pane view still use the full form (`detail(s)`), whose markup is unchanged.
- The do-not-redraw-while-typing guard covers the list and the pane. The text size is 17 px on wide screens (16 px elsewhere). Gig mode is unchanged and still single-column.

## Metronome beat dots and sound rescue
- The bar shows one dot per beat in the song's time signature (`perBar`, 4 for 4/4, 3 for 3/4, 6 for 6/8; up to 12). The current beat is lit until the next one, and beat 1 is green. On screens 700 px wide or more the dots sit between Start and Flash; on phones they are a full-width row above the controls and only show while the click is running. Gig mode sits underneath the bar, so the dots show there too.
- One scheduler (`tick`) keeps time on either the sound clock (`ctx.currentTime`) or, when the audio engine is not running, the phone's own timer (`performance.now`). It switches clocks by itself, so the dots keep time when sound is blocked and the sound clock takes over again as soon as sound comes back.
- `unlock()` starts the silent clip and `ctx.resume()` together inside the tap, waits at most 0.9 s, rebuilds the audio engine once and waits at most 0.7 s more, and returns whether sound is running. `start()` reacts at once (the button becomes Stop) and never waits forever. If sound is not running, a warning sits above the dots (silent switch, volume, open in Safari or Chrome) and the Test tone says the same. The debug lines under Test tone now include which clock the beat is using.
- The full-screen flash is now only the optional Flash tick box (off by default, with its warning).

## Small-phone layout
- Each song is one grid row: number, a title button (`data-a="toggle"`, opens the details), and the Click button. Under the title come the BPM and key, then the artist (which shortens first). The details panel starts with Move up and Move down, which replace the arrows that used to sit on every row.
- On touch screens (`pointer: coarse`) buttons, drop-downs and boxes are at least 44 px tall. The metronome bar shows its title row only while the click is running (the `on` class on `#bar`, set in `syncPlay`), so it is slim when idle. The page keeps 120 px of space at the bottom for it.
- One band: the header shows the band name (`#bandTitle`) instead of the band picker, which leaves room for the setlist picker. Two or more bands show the picker as before. Note `#bandName` is the create-band box in the menu, so the header label must not reuse that id.
- At 520 px wide or less the menu, band members and add-song screens fill the screen, with their Close row pinned at the top. The sync screen stays a small panel. Wider screens still get centred panels.
- A page-wide rule `[hidden]{display:none!important}` keeps anything marked hidden out of sight even when another style gives it a display value.

## Install help
- An Install card sits at the top of the first screen. It is hidden when the app runs installed (`navigator.standalone` or `display-mode: standalone`), when the person tapped Not now (`installHidden` in browser storage), and on desktop.
- iPhone and iPad: three steps (Share, Add to Home Screen, open the icon and sign in there) and a Copy link button. The app cannot detect WhatsApp's own browser, so the Copy link hint always shows; Facebook, Instagram, Line, WeChat, Snapchat, TikTok and Google app browsers are recognised and told to open Safari first. If an invite code is waiting, the card shows it, because the installed app has its own storage and cannot see the code saved in Safari.
- Android: the browser's `beforeinstallprompt` event is held and an Install app button calls it; there is no card until the browser offers it.
- The menu has How to install on your phone to bring the card back.

## Backend options (Supabase chosen)
| Option | Good for | Watch out for |
|---|---|---|
| Supabase (Postgres, row-level security, realtime) | Clear membership rules in SQL, easy history queries | You write the sync glue (now built as the queue above) |
| Firebase (Firestore, security rules, offline cache) | Built-in offline cache and realtime | Rules language is separate; history and ordering take care |
| Own API (e.g. on AWS) | Full control, fits multi-cloud experience | Most work to build and run |

## Database files and the order to run them
Run each file once, in order, in the Supabase SQL Editor as a new query. Later files are safe to run again.
These are not Edge Functions. Keep them in `sql/`, outside the public `app/` folder.

| File | Adds |
| --- | --- |
| v1 | Core tables, access rules, history, create and join band |
| v2 | Reason field on song changes and in the history |
| v3 | Instrument roles and root notes |
| v4 | Access levels, band colour, invites with a level, member management, ownership transfer |
| v5 | Last-used setlist per member |
| v6 | Cleans up a deleted band's history |
| v7 | Band logo |
| v8 | Band link ending (slug), unique across all bands |
| v9 | `invite_preview(code)`: the band name and level for a valid invite code, usable before sign-in |
| v10 | `songs.song_structure`: an optional free-text Song structure (text, not null, empty by default) |
| v11 | `song_views`: a person's remembered guitar or bass view of a song (one row per person per song, private to that person, with row-level security) |
| check_schema | A read-only checklist of which updates are present |

The `lookup-song` Edge Function is deployed separately under Edge Functions and only needs redeploying when its file changes.

## Security notes
- The publishable key in `config.js` is meant to be public. The secret or service-role key must never be in the app or repository.
- The GetSongBPM key and the Genius access token live only as Edge Function secrets (`GETSONGBPM_API_KEY`, `GENIUS_ACCESS_TOKEN`). Song Finder needs no key.
- All text from the database is escaped before display, links are accepted only if they start with http or https, and
  the band logo is checked again before it is shown.
- Emails contain codes, not links, and codes expire. Passwords must be at least 8 characters.
- `song_views` can be read and changed only by the person it belongs to, and only for their own bands. It holds a view name, not the chords themselves.

## Testing so far
Database changes were tested on a local PostgreSQL 16 with a stand-in for Supabase's auth layer: 97 permission checks
across owner, admin, editor, viewer and a non-member (with deliberately weakened rules to confirm the tests catch
mistakes), and separate checks for the last-used setlist, band deletion, the logo limits and the offline sync engine
(run against real row-level security). Screen logic was tested in Node with stand-ins. The sign-up and invite screen logic was run in a simulated browser (jsdom) against a stand-in for Supabase: 90 checks (sign-up and invites, the install card, the Enter key and Share and Email invite buttons, the welcome screen with one-step sign-up, confirm password, the fast start and the invitation page), plus 183 checks in headless Chromium (layout at phone, tablet and laptop sizes, the two-column view, the metronome with a real audio engine and with fake ones that refuse to start, the real Enter key, the launch screens with a slow fake server, the service worker against a server made slow, broken or offline, and the invitation page) at 360, 390, 820 and 1366 px wide that look at what is actually drawn (a page-wide rule keeps anything marked hidden out of sight even when another style sets its display), not stored in the
repository and never run on a real phone or the real database. None of these tests are in the
repository yet and nothing re-runs them automatically. Confirmed on the live app by you: the iPhone test and the
delete-song update. `core/` has its own 23 tests. The Song Structure change (SQL v10 and the details editor) and the removal of the
GetSongBPM footer link and the Root notes box have not been tested yet. The compact right-hand panel was measured in headless Chromium (Linux fonts) at 1920x1080, 1536x864 and 1366x768, not on a real desktop or tablet. The lyrics link suggestions were tested with 24 checks in headless Chromium against a stand-in for Supabase and the functions (suggest, review, use, replace prompt, remove, save, error fallback, viewer, phone layout) and the ranking was run on sample data, but the live Genius service, a real phone and a real signed-in session were not used.
SQL v11 (`song_views`) was run on an in-memory PostgreSQL (PGlite) with a stand-in for Supabase's auth layer: it runs twice without error, a person reads and writes only their own rows, another member and an outsider are refused, a row whose song and band do not match is refused, only guitar or bass is accepted, a signed-out visitor has no access, `updated_at` moves on a change and the rows go with the song (16 checks). The guitar or bass view, the progression link finder, Use with its overwrite question, and the gig mode switch were tested in a simulated browser (jsdom) with a stand-in database (about 35 checks, two-pane layout). Not tested: the real Supabase project, a real browser or any phone or tablet, the look of the switch, and whether the Songsterr and Ultimate Guitar search addresses land on a useful page.

## Running and changing it safely
1. For any change that includes SQL: run the SQL first, then upload the new `index.html`.
2. Update `app/index.html` and leave `config.js` alone.
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
- The install steps were written from how iOS and Android normally behave and have not been tried on a real phone yet; the wording of the iOS menus can change between versions.
- An invite link remembered in Safari does not reach the installed iPhone app, so those testers type the code. A mistyped email at sign-up cannot be recovered while email is off; the app only catches common domain typos.
- The home-screen icon is the same for every band.
- The guitar or bass choice is per song and person. Until SQL v11 is run it stays on one device. The suggested links are search pages, not specific songs, and a link and written notes share one box until a separate link field is built.

## Open questions
1. ~~PWA first or Expo first.~~ Answered: PWA first.
2. ~~Sign-in method.~~ Answered for now: email and password plus emailed codes. Google (and Apple) still open.
3. Which versions to show for a song (how to rank "well known").
4. Do removed songs and old history ever get pruned?
5. Web address and hosting: stay on GitHub Pages, or buy a domain and possibly move hosting.
6. Same-field conflicts: ask the person (current) or let the later change win (earlier design).
7. How long to keep history on the device.
