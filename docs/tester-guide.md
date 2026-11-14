# Setlist app: tester guide

## 1. Invite someone (one message)

**Easiest way: let the app write the message.** In Band members and access your invite code is already there (it is made the first time you open the screen). Tap **Share invite**
(on a phone this opens WhatsApp, Messages or Mail with the whole message ready) or **Email invite** (opens your mail app with the
message filled in, and you choose who to send it to). The message leads with an invitation link. The tester taps it, sees
"Join [your band]", types their email and a password, and taps **Accept invitation and join**. That is all: they are in the band.
The message also holds the invite code as a backup and a note on installing the app on an iPhone. The app does not send any email itself.

**If you would rather write it yourself** (copy, fill in the blanks)

> Hi [name]! I'd love your help testing a setlist app I've built for bands: songs with BPM, key and chords, a metronome,
> and a stage view. It's an early test version.
>
> 1. Tap this link: https://timlawless.github.io/setlists/#join-[CODE]
> 2. Enter your email and choose a password. That is all: you will be in the band.
>    iPhone: to install the app, open the link in Safari, tap Share, then Add to Home Screen, then open it from your home screen and sign in.
>
> Link not working? Open https://timlawless.github.io/setlists/, tap "I am new: create my account" and type this invite code: [CODE]
>
> Please message me here with anything odd, confusing or broken. Thank you!

**Copy buttons.** **Copy invite link** and **Copy code only** are there if you want to paste them somewhere yourself. The invite code stays the same, and keeps working, until you tap **Make a new code**, so you can send the same invitation again and again. Making a new code switches the old one off straight away. There is one code for Editors and one for Viewers. **Email invite** asks which mail to use on a computer (your email app, Gmail or Outlook, or copy the message).

## 2. Install it on your phone
When you open the link in a browser, the app shows an **Install** card at the top with the steps for your phone. You can follow
the card or the steps below. Tap **Not now** to hide it. To bring it back, open the menu (☰) and tap **How to install on your phone**.

**iPhone**
1. Open the link in **Safari**. Tapping a link in WhatsApp opens it inside WhatsApp, which hides the install option. If you do
   not see **Add to Home Screen** in step 3, tap **Copy link** on the card, open Safari and paste the link into the address bar.
2. Tap the **Share** button (the square with an arrow pointing up) at the bottom of Safari.
3. Scroll down the list and tap **Add to Home Screen**, then **Add**.
4. Close Safari and open the app from the new icon on your home screen. It opens full screen. The installed app is separate
   from Safari, so it asks you to sign in once. If you already joined in Safari, just sign in. If not, create your account there and type your invite code in the **Invite code** box.

**Android**
1. Open the link in Chrome.
2. Tap **Install app** on the card at the top. If you do not see the card, tap the **three dots** at the top right, then **Install app** or **Add to Home screen**.
3. Open the app from your home screen and sign in there.

You can also just use it in the browser without installing, but the installed version is the one to test.

## 3. Create your account and join the band
**If you were sent an invitation link:** tap it, type your email and a password (twice), and tap **Accept invitation and join**. You do not need a code, and your name is optional. Then skip to step 4. If your email already has an account, the app moves you to **Sign in** and adds you to the band when you sign in.

**If you have a code instead:**
1. Open the app. Tap **I am new: create my account**.
2. Fill in the boxes: your name (your bandmates will see it), your email (check the spelling: the app cannot email you while it is
   in testing), a password you will remember (at least 8 characters, typed twice) and the **Invite code** from your band leader. Tap
   **Show password** if you want to check it. If you opened an invite link, the code is already filled in.
3. Tap **Create my account**. You join the band straight away. If you did not type a code, you will see "Welcome! You are not in
   a band yet" with a box: type the code there and tap **Join band**.
4. Next time you open the app you stay signed in: it shows "Loading your setlists…" and then your setlist. If you were signed out it goes to **Sign in**. Forgot your password? Tap **Trouble signing in?**, or message the
   person who invited you.

## 4. Things to try
- Open a setlist and tap a song's title to open its details. Change the BPM, key, chords or notes, and tap **Save changes**. Tap **History** to see the change.
- Tap **▶ Click** on a song to start the metronome. Tap it again to stop. Try the **Flash** tick box (it shows a warning first).
- Open the menu (☰) and choose **your instrument role in this band**, then tap **Gig mode** and look at what it shows you.
- Add a song with **+ Add song**, open a song's details to move it **up** or **down**, and remove a song from the setlist.
- Optional: switch your phone to airplane mode, change a song, then switch it back on. The change should sync by itself.

### The metronome
Tap **▶ Click** on a song (or **Start** at the bottom). The big dots show the beat: one dot per beat in the bar, and the dot for beat 1 is green.
If you hear nothing, check that the side **silent switch** is off, turn the **volume** up, and open the app in **Safari** (iPhone) or **Chrome** (Android),
not inside WhatsApp or another app. If the sound is still blocked a note appears above the dots, and the dots keep time without sound. Open the ☰ menu and
tap **Test tone** at the bottom, then tell me what the lines under it say.

## 5. Things that don't work yet
- **"Forgot password?" and "Email me a sign-in code"** are still in development. Please remember your password. If you forget it, message me.
- There is **no undo** for deleting. Ask me if you delete something by mistake.
- On a **tablet or laptop** (a screen about 900 pixels wide or more) the setlist is on the left and the open song's details are on the right. Tap a song to see it. Gig mode still uses the single-column view.
- The **key and BPM lookup** can take several seconds and may not find every song. Check its values against the recording.

## 6. If something goes wrong
WhatsApp me with: what you tapped, what you expected, what happened, your phone model, and a screenshot if you can.

## 7. About your data
The app stores your name, your email and your band's songs and setlists. Only members of your band can see your band's data.
I can see the data in the database while I am testing. This is an early test, so keep your own copy of any setlist you
cannot afford to lose.
