# Roadmap

Tick items off as they are done. Read `architecture.md` first: it records the decisions and the reasons.

## Where things stand
- Free, never commercial. Devices: iPhone, Android, tablets. Backend: Supabase.
- Target is a PWA for band members. **PWA first or Expo first is still open** (step 2 decides it).
- Sharing is not needed at first but should arrive early so it can be tested with bandmates.

## Done
- [x] Interactive prototype (`prototype/`): bands, several setlists per band, song editing and reordering, original
      key/tempo with a version picker, YouTube link, lyrics link and lyrics text, sheet music and tab links, change history with restore,
      offline demo, light and dark themes, metronome with sound and flash.
- [x] `core/`: change history, offline queue, metronome scheduler and flash rule, link cleaner, sheet music link list. 23 tests.
- [x] Architecture notes and decisions.
- [x] Repo on GitHub.

## Next, in order
1. [ ] **PWA test page.** Built: `docs/pwa-test/` (see its README for hosting and the test script). It still has to be
       hosted and run on real devices. Open it on an iPhone, an Android phone and a tablet and check:
       - install flow (iOS: Add to Home Screen; Android: install prompt);
       - works offline after install;
       - metronome click timing using the browser audio clock and `BeatScheduler`;
       - screen wake lock, and whether the click keeps going when the screen locks;
       - flash on screen, and the ring/silent switch on iPhone muting sound;
       - tablet layout and landscape.
2. [ ] **Decide PWA first or Expo first** from step 1's results. Update `architecture.md`.
3. [ ] **Supabase schema and members-only rules.** Tables: users, bands, memberships (role), setlists, entries,
       changes (append-only), catalog cache. Row-level security so only members of a band can read or write its data.
       Write tests that prove an outsider cannot read or write anything, a member can, and only admins manage members.
4. [ ] **Milestone 1: solo app on the device** (PWA or Expo, per step 2). Screens from the prototype; data stored on
       the device; use `core/` for history, queue and metronome; tablet two-pane layout; lyrics section.
       Use random UUIDs for all ids and record every edit as a change with its author.
5. [ ] **Sharing for testing.** Sign-in, invite by typed code, sync by pushing the queue and pulling changes in
       server order, history shared across members. Test with real bandmates.
6. [ ] **Catalog lookup.** Provider interface and confidence merging in `core/` with tests, then an Edge Function
       using MusicBrainz (find versions) and GetSongBPM (tempo, key; link back required). Cache results.
7. [ ] **Polish.** Install guide for iPhone, wake lock on stage, "Auto" theme following the phone, high-contrast mode,
       stage view with large lyrics and chords, first-time warning for the Flash option.

## Notes for whoever picks this up
- Run `cd core && npm install && npm test` before and after changes. Keep `core/` free of platform code.
- Lyrics: never ship or fetch lyrics. See "Lyrics and links" in `architecture.md`.
- Source accuracy for tempo and key varies. Show a confidence level and let the band's own values win.
- Open questions are listed at the bottom of `architecture.md`.
