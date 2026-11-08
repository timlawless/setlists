# Alpha go-live checklist (first band, Tuesday)

This is a to-do list, not a program. There is nothing to run. Work through it from the top, do each step by hand, and
tick the box when it is done. Parts A and B are the install and the tests; part C is the last jobs before you invite anyone.

Decisions for the alpha: **no email setup** (the "Forgot password?" and "Email me a sign-in code" buttons stay, and you
tell testers they are in development), **Confirm email stays off**, and testers send problems to you on WhatsApp.

## A. Install (skip any step you have already done)
- [ ] **A1. SQL.** Supabase, SQL Editor, new query: paste all of `schema_v7_band_logo.sql`, Run. (Safe to run twice.)
      Do this before A3, because the new page asks for the logo column.
- [ ] **A2. Edge Function.** Supabase, Edge Functions, `lookup-song`: replace the code with the new `lookup-song.ts` and Deploy.
      Verify JWT stays off. A GetSongBPM key is not needed.
- [ ] **A3. App.** GitHub: upload the new `index.html` to `docs/setlist-pwa-v2/`. Leave `config.js` alone. Commit.
- [ ] **A4. Check the new page loaded.** Open the app in a private window. The line at the bottom of the page should say
      "BPM and key data from GetSongBPM and Song Finder". If not, the old copy is still showing.
- [ ] **A5. Leave email alone.** Authentication, Providers, Email: **Confirm email must stay off**, and do not connect SMTP.
      If Confirm email were on without working email, nobody could sign up.
- [ ] **A6. (Optional) Database check.** Run `check_schema.sql` as a new query. Every row should say true except the v5 and
      later rows you have not installed.

## B. Tests
Write down what you see. A short note is enough. Use a real phone for the first four.

### 1. Offline editing (phone, installed app)
- [ ] Open a setlist online, then turn on airplane mode. A chip saying **Offline** appears at the top.
- [ ] Change a song's BPM and tap Save. The message says it was saved on this device. The chip says **1 waiting**.
- [ ] Move a song down, then add a new song with + Add song, Create and add. The screen updates straight away.
- [ ] Close the app completely and open it again, still offline. Your changes are still shown.
- [ ] Turn airplane mode off. Within about 20 seconds the chip disappears. (Or tap the chip, then Sync now.)
- [ ] Open that song's History: the change is listed, with the reason "Edited offline" if you typed none.
- [ ] On a laptop, check the changes are there too.

### 2. Conflict (two accounts: A on the phone, B on the laptop)
- [ ] A goes offline and changes song X's BPM to 140 and adds a note.
- [ ] B (online) changes song X's BPM to 130.
- [ ] A reconnects. The chip says **Check sync (1)**. Tap it: it shows BPM, yours 140, theirs 130. The note was saved.
- [ ] Tap **Use mine**: BPM becomes 140. Repeat the conflict and tap **Keep theirs**: BPM stays as B set it.

### 3. Flash limit
- [ ] Tick **Flash** in the metronome bar. A warning appears the first time. Cancel: the box unticks. Tick again and accept.
- [ ] At 120 BPM the screen flashes on every beat. At 200 BPM it flashes only once per bar of four.

### 4. Install and join as a new tester (do this on both an iPhone and an Android phone)
- [ ] Follow `tester-guide.md` exactly with a brand-new account: install the app, sign up, join with an invite code.
- [ ] Note anything in the guide that was unclear or wrong, and fix the guide.

### 5. Access checks on the live site
- [ ] Make a **Viewer** invite code and join with a second account. That account sees the songs but has no Add, Save or reorder buttons.
- [ ] Sign up a third account and do not give it a code. It sees "No bands yet", and no songs or setlists.

### 6. Band logo
- [ ] As owner: Band members and access, Band settings, upload a PNG or JPG. It shows beside the band name and in gig mode.
- [ ] Remove it again if you do not want one.

### 7. Key and BPM lookup
- [ ] On a song's Details, type a title (for example Walk This Way) and tap **Look up key and BPM**. It can take 3 to 8 seconds.
- [ ] Matches show the source and a confidence level. Tap **Use**, then Save changes.
- [ ] If you see a message like "Song Finder answered 403", send it to me. "Song Finder is busy" means wait a few seconds.

### 8. Quick check that nothing else broke
- [ ] Sign in, switch band, switch setlist (the last-used one opens), open gig mode, start the metronome and hear the click.

## C. Before you invite anyone
- [ ] **Back up the data.** The free Supabase plan has no automatic backups. If you have Postgres tools, run `pg_dump` with
      the connection string from Project settings, Database. Otherwise open each table in the Table Editor and use Export
      as CSV (bands, band_members, band_invites, songs, song_links, setlists, setlist_songs, change_log, profiles).
      Repeat before every later update.
- [ ] **Keep a way back.** Keep the previous `index.html`. To roll back, re-upload it, or open the file's history on GitHub
      and restore the earlier version.
- [ ] **Create the band** with your own account (you become the owner). Add a few songs and a setlist so testers land on something.
- [ ] **Make the invite code on Tuesday morning.** Codes last 7 days and can be used by several people. Make an Editor code
      for the band and, if you want, a Viewer code for anyone who should only look.
- [ ] **Dry run.** One more pass through `tester-guide.md` with a fresh account on a phone that is not yours.
- [ ] **Send the guide** on WhatsApp, with the invite code.

## D. During the alpha
- **Problems arrive on WhatsApp.** Paste them to me with the phone model, what the person did and what happened. A screenshot helps.
- **A forgotten password** (the reset buttons need email, which is off): in the SQL Editor run
  `update auth.users set encrypted_password = extensions.crypt('TempPass-123', extensions.gen_salt('bf')) where email = 'their@email.com';`
  and tell them the temporary password, then ask them to change it in the menu. I could not test this against Supabase
  itself, so try it first on a throwaway account of your own. If it says the function does not exist, tell me.
- **Before any update:** back up, run any SQL first, then upload the page, and check it in a private window.
- **Keep the project active.** A free Supabase project pauses after a week without use. An active band will not hit this.

## E. Later (not for the alpha)
Email sending with a domain you own, the three email templates, switching Confirm email on, and then testing sign-in
codes, password reset and sign-up confirmation. `supabase_email_templates.txt` is ready for that.
