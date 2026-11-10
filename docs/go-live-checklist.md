# Alpha go-live checklist (first band, Tuesday)

A to-do list, not a program: nothing to run. Work from the top, do each step by hand, tick the box when it is done.

Decisions for the alpha: no email setup (the "Forgot password?" and sign-in code buttons stay, and testers are told they
are in development), Confirm email stays off, and testers send problems to you on WhatsApp.

The tests for offline editing, conflicts, the flash limit, the logo, access levels and the first lookup passed on the
previous version. This release moves the app to the root address, adds band links and changes the song lookup, so the
checks below focus on those and then repeat a quick sanity pass.

## A. Install this release, in this order
- [ ] **A1. Back up the data** (Table Editor, Export as CSV for each table, or `pg_dump`). The free plan has no automatic backups.
- [ ] **A2. SQL.** Supabase, SQL Editor, new query: paste all of `schema_v8_band_link.sql`, Run. (Safe to run twice.)
- [ ] **A3. Edge Function.** Edge Functions, `lookup-song`: replace the code with the new `lookup-song.ts` and Deploy. Verify JWT stays off.
- [ ] **A4. Move the app to the top of `docs/`.**
  1. Unzip `docs-upload.zip` on your computer.
  2. On GitHub open the `docs` folder, choose Add file, Upload files, and drag in everything from inside the `docs-upload`
     folder: `index.html`, `config.js`, `sw.js`, `manifest.webmanifest`, the three `icon-` pictures, and the
     `setlist-pwa-v2` folder. Commit.
  3. Open `docs/setlist-pwa-v2/` and delete `sw.js`, `config.js`, `manifest.webmanifest` and the icons from it. Keep
     `index.html`: it is now a small page that sends old links to the new address.
  4. `config.js` in the zip holds the same Supabase address and key you used before. Compare it with your old one.
- [ ] **A4b. Sign-up, invite and install-help update.** Upload the newer `index.html` over `docs/index.html` (Add file, Upload files, Commit). No SQL, and `config.js` and `sw.js` stay as they are. Do this after A4, then open the app in a private window.
- [ ] **A5. Check the new address.** Open https://timlawless.github.io/setlists/ in a private window: the sign-in page appears,
      and the footer says "BPM and key data from GetSongBPM and Song Finder".
- [ ] **A6. Your own phone and laptop.** The old home-screen icon points at the old address. Delete it, open the new address
      and add it to the home screen again. Do the same for any browser tab you keep open.
- [ ] **A7. Leave email alone.** Confirm email stays off and SMTP stays unconnected.

## B. Tests
### 1. The new address
- [ ] Sign in at the root address. Your bands and setlists are there.
- [ ] Open the old address (`.../setlists/setlist-pwa-v2/`): it sends you to the root address.
- [ ] Install it fresh on an iPhone and on an Android phone and open it from the home screen.

### 2. Band link
- [ ] As owner: Band members and access, Band settings. Type an ending such as `wc` and tap **Save link**. The address bar shows `#wc`.
- [ ] Tap **Copy link**. Open the copied link in a private window, sign in: the band opens by itself.
- [ ] Switch to another band: the address changes (or the `#` part disappears if that band has no link).
- [ ] With a second account that is in the band: the link opens the band. The band link row shows in Band members, but the settings do not.
- [ ] With an account that is not in the band: the link shows a message saying you are not a member, and reveals nothing else.
- [ ] Try an ending that is taken by another band, one with capital letters or spaces, and a reserved one such as `admin`: each is refused with a clear message.

### 3. Song lookup
- [ ] On a song's Details, type **I Gotta Feeling** and the artist **Black Eyed Peas**, tap **Look up key and BPM**. The Black Eyed Peas recording is first in the list.
- [ ] Tap **Get tempo and key** on it. The tempo and key appear with a confidence level. Tap **Use**, then Save changes.
- [ ] Try the same title without an artist: you pick the right recording from the list yourself.
- [ ] If a message says Song Finder is busy, wait a few seconds and try again.

### 4. Quick check that nothing else broke
- [ ] Sign in, switch band and setlist, open gig mode, start the metronome (click is audible), make one offline edit and watch it sync.

### 5. Sign-up and invite
- [ ] As owner: Band members and access, choose Editor, tap **New invite code**. **Copy invite link** and **Copy code only** buttons appear. Paste the link somewhere to read it: it ends `#join-` and the 8-character code.
- [ ] Open the invite link in a private window, signed out: the sign-in page says you have been invited to join a band.
- [ ] Sign up with a fresh test email. The app adds you to the band by itself and says you have joined it. The code is gone from the address bar.
- [ ] Sign up a second fresh account from the plain address. You see "Welcome! You are not in a band yet" with a code box. Type the code in lower case with a space in the middle: it still joins.
- [ ] Type a wrong code: a friendly message, and nothing changes.
- [ ] Sign up with `name@gmial.com`: the app asks "Did you mean gmail.com?". A blank name, a short password and an email with no `@` are each refused with a clear message.
- [ ] Tick **Show password**: the password becomes visible. Sign in with a wrong password: the message says to tap Sign up if you are new.
- [ ] On the sign-in page type an email and password and press Enter: a known user signs in. Try an unknown email: the message asks you to type your name and the cursor jumps to the name box. Press Enter there to sign up.
- [ ] After making a code tap **Share invite**. On a phone the share sheet opens with the whole message (app address, iPhone steps, code, invite link). On a laptop the message is copied: paste it somewhere to read it.
- [ ] Tap **Email invite**: your mail app opens with a subject and body filled in and no recipient. (A laptop with no mail program set up may do nothing.)
- [ ] On an iPhone: install first, sign up inside the installed app, then type the code on the card. (A code remembered in Safari does not reach the installed app.)
- [ ] Try a band link ending that starts with `join-`: it is refused.

### 6. Install help (needs real phones)
- [ ] iPhone, in Safari, app not installed: an Install card with three steps appears above the sign-in page. Follow it: Add to Home Screen works and the icon opens the app full screen.
- [ ] iPhone, link opened from inside WhatsApp: see whether Add to Home Screen is missing. If it is, tap **Copy link** on the card, paste it in Safari: the page opens there. (The app cannot tell WhatsApp's own browser from Safari, so the Copy link hint always shows on iPhone.)
- [ ] Open the installed app: no card. Sign in once. Menu, **How to install on your phone**: it says the app is already installed.
- [ ] **Not now** hides the card, and it stays hidden after a reload. The menu button brings it back.
- [ ] Android, Chrome: an **Install app** button appears on the card and installs the app. (It only appears when Chrome offers installation.)
- [ ] On a laptop browser: no Install card.

## C. Before you invite anyone
- [ ] Keep the previous `index.html` so you can roll back (GitHub keeps every version).
- [ ] Create the band with your account. Choose its link ending. Add a few songs and a setlist.
- [ ] Make the invite code on Tuesday morning (codes last 7 days and can be used by several people). In Band members and access tap **New invite code**, then **Copy code only** (and **Copy invite link** if you want the link).
- [ ] Dry run `tester-guide.md` with a fresh account on a phone that is not yours.
- [ ] Send the two WhatsApp messages from `tester-guide.md` section 1: the link and install steps first, then the code on its own.

## D. During the alpha
- **Problems arrive on WhatsApp.** Paste them to me with the phone model, what the person did and what happened.
- **A forgotten password** (the reset buttons need email, which is off): in the SQL Editor run
  `update auth.users set encrypted_password = extensions.crypt('TempPass-123', extensions.gen_salt('bf')) where email = 'their@email.com';`
  and tell them the temporary password, then ask them to change it in the menu. I could not test this against Supabase
  itself, so try it first on a throwaway account of your own.
- **Before any update:** back up, run any SQL first, then upload, and check in a private window.
- **Keep the project active.** A free Supabase project pauses after a week without use.

## E. Later
Email sending with a domain you own, the three email templates, Confirm email on, and then testing sign-in codes and reset.
When email is set up, use the root address as the Site URL in Supabase. If you contact GetSongBPM again, give them the root
address: the link back to them is on that page.
