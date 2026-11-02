# Architecture notes

Decisions so far are marked **Decided**. Everything else is a recommendation to confirm.

## Product decisions
- **Decided:** the app will eventually be offered to band members as a PWA (installable web app).
- **Not decided:** PWA first or Expo (React Native) first. A PWA first is recommended because it matches the plan and makes testing easy (testers open a link).
- **Decided:** Supabase for the backend (Postgres, row-level security, sign-in).
- **Decided:** the app is free and never commercial.
- **Decided:** sharing is not needed at first, but should arrive early so it can be tested with bandmates.
- **Decided:** a user can belong to several bands. Each band has several setlists (one per gig or arrangement).
- **Decided:** all band members can edit setlists. Every change is recorded and can be restored.
- **Decided:** offline use matters (venue Wi-Fi is unreliable).
- Original tempo and key are filled in from a song catalog, with a version picker when a song has several
  well-known versions (for example Walk This Way: Aerosmith or Run-DMC). The band can then edit them.
  Lookup is a convenience, not the core feature.

## Data model
```
User ──< Membership >── Band ──< Setlist ──< Entry
                                  Setlist ──< Change   (append-only history)
```
- **Entry** holds the band's own title, artist, tempo, key, chords, notes and link, plus the catalog `original`
  it was seeded from. Arrangement edits never touch the shared catalog.
- **Membership** = (user, band, role). Roles are `admin` and `member`. Both can edit setlists; admins manage members.
- **Change** is one of add, remove, move or edit. Edits store the new values (`patch`) and the old ones (`inverse`).

## Privacy: who can see what
A band's data must only reach its members, and that has to be enforced **on the server**, not in the app.
- Every read and write checks that the signed-in user has a Membership row for the band that owns the setlist.
- With Postgres this is row-level security keyed on `membership(user_id, band_id)`. With Firestore it is security rules.
- The app only asks for bands the user belongs to, but nothing relies on that.
- Joining is by invite (code or link) created by an admin. Removing a member revokes access immediately.

## Versioning (change history)
- History is an append-only list of `Change` records. Restoring creates a **new** change that applies the inverse,
  so nothing is ever rewritten and the restore itself shows up in history.
- The server assigns each change a sequence number. Clients apply changes in that order (`replay`).
- Edits are field-level. Two members changing different fields of one song never conflict.
  If both change the same field, the later one wins and both stay in history.
- Restoring an edit sets those fields back to the values they had at that time. That can overwrite a later
  edit to the same field, which is why the restore is itself recorded.
- Per-change author and time give the "Last changed by Jo, 2 days ago" line.

## Offline
- The device database is the source of truth for the UI. Reads never wait on the network.
- Changes made offline go into `OfflineQueue` (persisted, ordered) and are flushed oldest first when online.
- Change ids are idempotency keys: the server ignores a change it has already seen, so retries are safe.
- Flush stops at the first failure to keep order. The UI shows how many changes are waiting.
- Needs a decision: sync transport (see stack options) and how long to keep history on device.

## Metronome
- A JS timer is not accurate enough for a click. `BeatScheduler` wakes often but hands the audio layer an exact
  time for each beat (lookahead scheduling), so timer jitter does not move the beat.
- Flash is an option for drummers who cannot hear the click. `flashAllowed` keeps flashing to three per second or
  fewer: every beat up to 180 BPM, beat 1 only above that. Add a warning the first time Flash is switched on.
- Needs a native audio path for accurate playback (to be chosen when the app is built); background play and
  lock-screen behaviour differ between iOS and Android and need testing on real devices.

## Catalog lookup (original key and tempo)
Server-side only (a Supabase Edge Function), with results cached in a `catalog_versions` table.
1. Find the song and its well-known versions with MusicBrainz. Free for non-commercial use, one request per second,
   needs a descriptive User-Agent, core data is CC0. It has no tempo or key.
2. Get tempo, key and time signature for each version from GetSongBPM. Free API key, but a visible link back to
   GetSongBPM is required.
3. Merge into a confidence level: two sources agree = high, one source = medium, conflict = "check".
   Flag half-time ambiguity (for example 85 or 170 BPM).
4. The band's own values are stored separately and always win ("Original" vs "Changed for your band").

Not usable: Spotify audio features (closed to new apps since 27 Nov 2024) and AcousticBrainz (frozen since 2022).
Chords stay manual. Later options: a second tempo source, band corrections, and analysing a band's own recording
with Essentia (open source, has a JavaScript build).

Providers sit behind a small interface so one can be swapped if its terms change. Check each provider's terms on
caching before storing results. Source accuracy varies, so values should be checked against the recording.
YouTube links start as a search for the chosen version and can be replaced with a specific video.

## PWA notes (iPhone)
Sources disagree on some details, so test on real iPhones early.
- No automatic install prompt on iOS: users add the app to the Home Screen by hand. Show a short install guide.
- Web Push only works for installed apps.
- Sound only plays after a tap (fine: the metronome has a Start button).
- Screen wake lock is reported to work on recent iOS (sources differ on the version). The click will likely stop if
  the screen locks, so use wake lock on stage.
- Installed apps have more stable storage. Shared data lives in Supabase, so a cleared cache costs a re-download.
- Links may not open an installed PWA, so invites should work by typing a code.

## Backend options (Supabase chosen)
| Option | Good for | Watch out for |
|---|---|---|
| Supabase (Postgres, row-level security, realtime) | Clear membership rules in SQL, easy history queries | You write the sync glue |
| Firebase (Firestore, security rules, offline cache) | Built-in offline cache and realtime | Rules language is separate; history and ordering take care |
| Own API (e.g. on AWS) | Full control, fits multi-cloud experience | Most work to build and run |

## Open questions
1. PWA first or Expo first.
2. Sign-in method (email link, Apple and Google sign-in).
3. Which versions to show for a song (how to rank "well known").
4. Do removed songs and old history ever get pruned?
