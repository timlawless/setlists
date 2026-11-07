# Go-live and test checklist

For the updates that are built but not yet confirmed on the live site: sign-in codes and reset, the band logo, offline
editing, the flash limit, and the backup key and BPM lookup. Tick each box as you go. Test on a real phone as well as a laptop.

## A. Install, in this order
- [ ] **1. SQL.** Supabase, SQL Editor, new query: paste all of `schema_v7_band_logo.sql`, Run. (Safe to run twice.)
- [ ] **2. Email sending.** Authentication, SMTP Settings: connect your email service and send a test to an address that is
      not on your Supabase team.
- [ ] **3. Email templates.** Authentication, Email Templates: paste in the three templates from `supabase_email_templates.txt`.
- [ ] **4. Confirm email.** Authentication, Providers, Email: switch **Confirm email** on. Do this last, and only after step 2 works.
- [ ] **5. Edge Function.** Edge Functions, `lookup-song`: replace the code with the new `lookup-song.ts` and Deploy.
      Leave the secret as it is. Verify JWT stays off. (You do not need a GetSongBPM key for it to work now.)
- [ ] **6. App.** GitHub: upload the new `index.html` to `docs/setlist-pwa-v2/`. Leave `config.js` alone. Commit.
- [ ] **7. Check the new page loaded.** Open the app in a private window. The line at the bottom of the page should say
      "BPM and key data from GetSongBPM and Song Finder". If it does not, the old copy is still showing.

## B. Tests
Write down what you see for each one. A short note is enough.

### 1. Offline editing (phone, installed app)
- [ ] Open a setlist while online. Turn on airplane mode. A chip saying **Offline** appears at the top.
- [ ] Open a song, change its BPM, tap Save. Message says it was saved on this device. Chip says **1 waiting**.
- [ ] Move a song down, then add a new song with + Add song, Create and add. The screen updates straight away.
- [ ] Close the app completely and open it again, still offline. Your changes are still shown. Chip still says waiting.
- [ ] Turn airplane mode off. Within about 20 seconds the chip disappears. (Or tap the chip, then Sync now.)
- [ ] Open the song's History: the BPM change is listed, with the reason "Edited offline" if you typed none.
- [ ] On a laptop, check the changes are there too.

### 2. Conflict (needs two accounts: A on the phone, B on the laptop)
- [ ] A goes offline. A changes song X's BPM to 140 and adds a note.
- [ ] B (online) changes song X's BPM to 130.
- [ ] A reconnects. Chip says **Check sync (1)**. Tap it: it shows BPM, yours 140, theirs 130. The note has been saved.
- [ ] Tap **Use mine**: BPM becomes 140 and the History reason says an offline edit was kept over a conflicting change.
- [ ] Repeat the conflict and tap **Keep theirs**: BPM stays as B set it.

### 3. Flash limit
- [ ] Tick **Flash** in the metronome bar. A warning appears the first time. Cancel: the box unticks. Tick again and accept.
- [ ] At 120 BPM the screen flashes on every beat.
- [ ] Set 200 BPM: the screen flashes only once per bar of four, not on every beat. (The small dot still beats every time.)

### 4. Sign-in codes and reset (needs the email setup)
- [ ] Sign out. Tap **Forgot password?** with your email. A code arrives by email. Enter it with a new password. You are signed in.
- [ ] Sign out. Tap **Email me a sign-in code**, enter the code. You are signed in.
- [ ] Sign up a new test account. A confirmation code arrives. Enter it.
- [ ] Menu, Change password: works, and you can sign in with the new one.
- [ ] Repeat the first two in the installed iPhone app.

### 5. Band logo
- [ ] As owner or admin: Band members and access, Band settings, upload a PNG or JPG. It appears beside the band name and at the top of gig mode.
- [ ] As an editor or viewer: you see the logo but have no upload control.
- [ ] Remove the logo: it disappears.

### 6. Key and BPM lookup
- [ ] Open a song's Details, type a title (for example Walk This Way), tap **Look up key and BPM**. It can take 3 to 8 seconds.
- [ ] Matches appear, each showing the source (Song Finder or GetSongBPM) and a confidence level. Tap **Use**, then Save changes.
- [ ] Look up the same song again within ten minutes: the answer is instant.
- [ ] Try a song with only a title and then with the artist as well.
- [ ] If you see "Song Finder is busy", wait a few seconds and try again. If you see a message like "Song Finder answered 403",
      send it to me: it would mean their bot protection is blocking the Supabase servers.

### 7. Quick check that nothing else broke
- [ ] Sign in, switch band, switch setlist (the last-used one opens), open gig mode, start the metronome and hear the click.

## C. Report back
```
Installed all steps A1 to A7: yes / no (which failed:)
1 Offline editing: pass / fail (notes:)
2 Conflict: pass / fail
3 Flash limit: pass / fail
4 Sign-in codes and reset: pass / fail / not tested
5 Logo: pass / fail
6 Lookup: pass / fail (source shown:, time taken:)
7 Quick check: pass / fail
Anything odd:
```
