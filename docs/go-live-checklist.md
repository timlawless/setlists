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
- [ ] As owner: Band members and access, choose Editor, tap **New invite code**. **Share invite**, **Email invite**, **Copy invite link** and **Copy code only** appear. Paste the link somewhere to read it: it ends `#join-` and the 8-character code.
- [ ] Open the plain address in a private window, signed out: you see "Welcome to Setlist" with two big buttons and no form yet.
- [ ] Tap **I am new: create my account**: the card has a coloured top band, a welcome line, and name, email, password, confirm password and invite code boxes with one **Create my account** button. Tap **I already have an account** under it: the card turns plain, the name, confirm and code boxes go, and one **Sign in** button and **Trouble signing in?** appear.
- [ ] Fill in the create form with a fresh test email, the code typed in lower case with a space in the middle, and tap **Create my account**. You join the band in one go and see "You have joined ...".
- [ ] Repeat with a second fresh email and the code box left empty: you land on "Welcome! You are not in a band yet" with a code box. Type the code there: it joins. Repeat once with a wrong code: a friendly message, the account is still made, and the code box stays.
- [ ] Open the invite link in a private window, signed out: you go straight to the create form with the code already filled in and a note that you have been invited.
- [ ] Reload the page after signing in once, then sign out: you land on the sign-in form, not the first-visit buttons.
- [ ] On the sign-in form type an email and password and tap the keyboard's **Go** (or Enter): a known user signs in. Try a wrong password or an unknown email: a message stays on screen, tells new people to tap **I am new: create my account**, and opens **Trouble signing in?**. Do this on a real iPhone and a real Android phone, not only a laptop.
- [ ] In the create form the keyboard key reads **Next** on every box except the invite code box, where it reads **Go**. Next moves down the form; Go creates the account. Type two different passwords and tap Go: it says the passwords do not match and nothing is created.
- [ ] Sign up with `name@gmial.com`: the app asks "Did you mean gmail.com?". A blank name, a short password and an email with no `@` are each refused with a clear message.
- [ ] Tick **Show password**: the password becomes visible.
- [ ] After making a code tap **Share invite**. On a phone the share sheet opens with the whole message (app address, iPhone steps, code, invite link). On a laptop the message is copied: paste it somewhere to read it.
- [ ] Tap **Email invite**: your mail app opens with a subject and body filled in and no recipient. (A laptop with no mail program set up may do nothing.)
- [ ] On an iPhone: install first, then create your account inside the installed app and type the code in the **Invite code** box. (A code remembered in Safari does not reach the installed app.)
- [ ] Try a band link ending that starts with `join-`: it is refused.

### 6. Install help (needs real phones)
- [ ] iPhone, in Safari, app not installed: an Install card with three steps appears above the sign-in page. Follow it: Add to Home Screen works and the icon opens the app full screen.
- [ ] iPhone, link opened from inside WhatsApp: see whether Add to Home Screen is missing. If it is, tap **Copy link** on the card, paste it in Safari: the page opens there. (The app cannot tell WhatsApp's own browser from Safari, so the Copy link hint always shows on iPhone.)
- [ ] Open the installed app: no card. Sign in once. Menu, **How to install on your phone**: it says the app is already installed.
- [ ] **Not now** hides the card, and it stays hidden after a reload. The menu button brings it back.
- [ ] Android, Chrome: an **Install app** button appears on the card and installs the app. (It only appears when Chrome offers installation.)
- [ ] On a laptop browser: no Install card.

### 7. Small-phone layout (needs a real phone)
- [ ] Setlist: about four songs fit on the screen with the metronome bar showing, and each row is easy to read. BPM and key come first, then the artist.
- [ ] Tap a song's title: its details open, with **Move up** and **Move down** at the top. Tap the title again to close them.
- [ ] Every button and box is easy to hit with a thumb, with no mis-taps between neighbours.
- [ ] Tap **▶ Click**: the metronome bar grows to show the song title and the button says **■ Stop**. Stop it: the bar shrinks again.
- [ ] Open the menu (☰): it fills the screen. Scroll to the bottom: **Close** is still at the top. Try **Band members and access** and **+ Add song** the same way.
- [ ] With one band the top bar shows the band name and the setlist picker. Turn the phone sideways: nothing is cut off or hidden behind the metronome bar.

### 8. Metronome dots and sound (needs real phones)
- [ ] Tap **▶ Click** on a 4/4 song: four big dots, one lights on each click, beat 1 is green, and the lit dot lines up with what you hear. Stop: the dots go dark.
- [ ] A 3/4 song shows three dots and a 6/8 song shows six.
- [ ] On a tablet or laptop the dots sit in the middle of the metronome bar all the time. On a phone they only appear while the click is running, in a row above the controls.
- [ ] Gig mode: start the click: the dots still show at the bottom.
- [ ] iPhone: with the side silent switch ON, tap **▶ Click**: you should still hear it (the app asks iOS to play sound anyway). Write down your iOS version.
- [ ] iPhone: open the page inside WhatsApp and tap **▶ Click**. Either you hear it, or a warning appears above the dots and the dots keep flashing.
- [ ] Menu, **Test tone**: you hear a beep, and the lines under it say `audio: running`.
- [ ] Ask the tester who heard and saw nothing for their iPhone model, iOS version, browser, and what the `audio:` line says after **Test tone**.

### 9. Tablet and laptop layout (needs a real tablet or laptop)
- [ ] Tablet held sideways (about 1000 px wide or more) or a laptop: the setlist is on the left and the first song's details are on the right, with the metronome dots along the bottom.
- [ ] Tap a different song: the right side switches to it and the chosen row has a green outline. Tap the chosen row again: the details stay.
- [ ] Edit a field in the right side and tap **Save changes**: it saves. **Move up**, **Move down**, **Lookup** and **Remove from setlist** all work from there.
- [ ] Scroll the list: the right side stays in view and scrolls by itself if it is tall. Nothing is hidden behind the metronome bar.
- [ ] Turn a tablet from sideways to upright: the right side goes away and the open song's details appear inside its row. Turn it back: the right side returns.
- [ ] Text is a little larger and easy to read from arm's length.

### 10. Fast start and saved sign-in (needs real phones)
- [ ] Sign in once, close the app completely, reopen it: you should see your setlist almost at once, and the sign-in card should never flash up. If your phone had to wait for the server you may see "Loading your setlists…" instead, never the sign-in card.
- [ ] Switch on airplane mode, close and reopen the app: your saved setlist still shows.
- [ ] Reopen the app on a slow connection: the setlist appears first and quietly refreshes a moment later. If you were typing in a song when the refresh arrived, your typing must not be wiped.
- [ ] If the server no longer accepts your saved login (for example after a long time), you land on the sign-in screen with the message "Your saved sign-in has expired. Please sign in again."
- [ ] Ask a tester who said "it looks like it's making me log in again" to try the new version and tell you if it still looks that way.

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
