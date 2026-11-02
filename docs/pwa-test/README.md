# PWA test page

A small installable web page that checks what an installed web app can do on a real phone or tablet.
It decides roadmap step 2 (PWA first or Expo first). Nothing is sent anywhere; the report is copied by you.

## Put it online (HTTPS is required)
**GitHub Pages:** in the repo go to Settings, then Pages. Under "Build and deployment" choose
"Deploy from a branch", branch `main`, folder `/docs`, then Save. After a minute the page is at
`https://YOUR-USERNAME.github.io/YOUR-REPO/pwa-test/`. On a free GitHub account Pages needs a public repo.
The repo contains no secrets, but make it public only if you are happy with that.

**If you prefer not to make the repo public:** drag the `docs/pwa-test` folder onto Netlify Drop
(app.netlify.com/drop) or upload it to Cloudflare Pages. Both give an https link.

## Test script (about 15 minutes per device)
Do this on an iPhone, an Android phone and a tablet.
1. Open the link in the browser (Safari on iPhone and iPad, Chrome on Android).
2. **Install.** iPhone and iPad: Share, then Add to Home Screen. Android: tap Install app (button or browser menu).
3. Close the browser. Open the app from its new home screen icon. Section 1 should say "Running installed: yes".
4. **Offline.** Turn on airplane mode, close the app completely, open it again from the icon. It should still open.
5. **Metronome.** Tap Start at 120 BPM. Do you hear a click? On iPhone, flip the ring/silent switch and try again.
   If it is silent, tick "Try silent-switch fix", Stop, and Start again.
6. **Screen lock.** Start the metronome, lock the phone for 30 seconds, unlock. Read "Gaps over 0.5 s" and
   "Audio clock behind". Did you hear the click while locked?
7. **Flash.** Tick Flash and run at 120 BPM and then at 200 BPM. At 200 it should flash on beat 1 only.
8. **Keep screen awake.** Set the phone's auto-lock to 30 seconds, tap the button in section 4, leave the
   app untouched for 2 minutes. Did the screen stay on? (Remember to set auto-lock back afterwards.)
9. **Rotate** the device and check the layout line (tablet layout starts at 768 px).
10. Fill in section 6, tap **Copy report**, and paste it into your chat with Claude or another agent.
11. **A week later**, open the installed app again and check that "First opened" and "Times opened" survived.
    This shows whether iPhone keeps saved data for an installed app.

## Files
`index.html` (page), `app.js` (tests; the `BeatScheduler` is a plain-JS copy of `core/src/metronome.ts`),
`sw.js` (offline cache; bump `CACHE` when any file changes), `manifest.webmanifest`, icons.

## What was already checked
In headless Chromium on a computer: the service worker takes control, files are cached, the page opens offline,
the metronome schedules beats without late ones, and the report is generated. Nothing has been checked on a real
iPhone, Android phone or tablet. That is what this page is for.
