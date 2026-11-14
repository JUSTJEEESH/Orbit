# Orbit 2.0 — Release Checklist

Everything here is something only you can do: it needs your Apple developer
account, your Mac, or a real iPhone. Do the steps in order. Each says
**where** to do it.

The automated checks run on every push (GitHub → Actions → CI). They build
the app and run the test suite, including the tests that open a real 1.x
database with 2.0 and check that every memory, task, tag, photo/recording
reference and insight survives. **Don't ship a build whose CI run is red.**

---

## 1. Turn on iCloud for the app (one time, ~10 minutes)

2.0 can sync memories through the user's own iCloud. For that, Apple needs
to know Orbit uses iCloud.

1. On your Mac: `git pull`, then `xcodegen generate`, then
   `open Orbit.xcodeproj`.
2. Xcode → select the **Orbit** target → **Signing & Capabilities**.
3. You should see **iCloud** listed (it comes from the entitlements file).
   If it shows a red error, click **+ Capability → iCloud**.
4. Under iCloud, tick **CloudKit**. In **Containers**, make sure
   `iCloud.com.joshgreen.orbit` is ticked. If it isn't listed, click **+**
   and type exactly `iCloud.com.joshgreen.orbit`.
5. You should also see **Push Notifications** and **Background Modes →
   Remote notifications** (both come from the project). If Push
   Notifications shows an error, click **+ Capability → Push
   Notifications**.
6. Xcode registers all of this with Apple automatically (automatic signing).

> If you skip this, Orbit still works. The iCloud toggle shows "iCloud isn't
> available right now" and every memory stays safely on the iPhone. Nothing
> is lost; sync just doesn't start.

## 2. Create the iCloud database schema (one time, before release)

1. In Xcode, run Orbit **on your own iPhone** (not the simulator), signed in
   to iCloud.
2. In the app: Settings → **iCloud → Sync with iCloud** → on. Capture one
   memory of each kind (text, voice, photo, link). Wait a minute.
3. Go to **icloud.developer.apple.com** → CloudKit Console → choose
   `iCloud.com.joshgreen.orbit` → **Schema**. You should see record types
   like `CD_MemoryEntity` in the **Development** environment.
4. Click **Deploy Schema Changes…** → deploy to **Production**.

> **This step is easy to forget, and it matters.** App Store builds talk to
> the Production database. Without the deploy, sync silently doesn't work
> for customers. Their data stays safe on their iPhones, but they won't get
> sync.

## 3. Upgrade rehearsal on a real iPhone (the most important test)

This is the test that proves current users keep their data.

1. On a test iPhone, install **Orbit 1.x from the App Store**. If your own
   phone already has it with real memories, even better: **back up the phone
   first** (Settings → your name → iCloud → iCloud Backup → Back Up Now).
2. Use 1.x for real: text, voice notes, photos, a link, a sealed letter,
   tasks (including one synced to Reminders), a few tags. If you can, also
   save something with **Siri** ("Capture to Orbit") and from the
   **Apple Watch**.
3. Install the **2.0 TestFlight build** on top. TestFlight replaces the app
   and keeps its data.
4. Open it and check:
   - [ ] Every memory is there: same count, text, photos, voice notes play.
   - [ ] Sealed letters are still sealed.
   - [ ] Tasks are there, completed ones still completed.
   - [ ] Theme, notification time and Reminders/Calendar toggles are unchanged.
   - [ ] You did **not** see onboarding again.
   - [ ] What's New appears once. If you saved anything with Siri in 1.x,
         it says "We found N lost memories" and they're in the timeline.
   - [ ] Watch voice notes now have transcripts (give it a minute).
   - [ ] Delete a memory → **Undo** works → delete again →
         Settings → Your data → **Recently Deleted** → Restore works.
   - [ ] Settings → Your data → **Export Everything** produces a zip you can
         open in Files (journal, `orbit.json`, `media` folder).
   - [ ] Quit and reopen the app: everything is still there.

## 4. Fresh-install test

- [ ] Delete Orbit, install the TestFlight build fresh.
- [ ] Onboarding runs, then the iCloud question, then the app.
- [ ] Capture a memory and find it with Search.

## 5. Sync test (needs two devices, or delete + reinstall)

- [ ] Turn on iCloud sync on device A. Capture a memory.
- [ ] On device B (same Apple ID), install, turn on sync. Wait 1–2 minutes;
      the memory appears.
- [ ] Or: delete Orbit from device A, reinstall, turn on sync. Your memories
      come back (text, tags, tasks; photos/recordings stay local in 2.0).
- [ ] **With sync on**, share a link from Safari into Orbit, share a photo
      from Photos, and say "Capture to Orbit" to Siri. All three must
      appear in the timeline (the Share Extension and Siri write to the
      store while the app owns the iCloud connection; this confirms the
      two cooperate on a real device).

## 6. App Store Connect

- [ ] Version **2.0**. In `project.yml` set `MARKETING_VERSION: "2.0"` and
      `CURRENT_PROJECT_VERSION: "1"`, then `xcodegen generate`, archive,
      upload.
- [ ] Update the description: iCloud sync is now real and opt-in.
      "Photos and recordings stay on your iPhone" for now.
- [ ] App Privacy questionnaire: unchanged. iCloud sync stores data in the
      user's own private iCloud, which Apple doesn't count as collection by
      you.
- [ ] What's New text (suggestion):
  ```
  Orbit 2 is here.

  • Sync with iCloud — your memories on all your devices, stored privately in your own iCloud.
  • Nothing lost by accident — Undo any delete, and Recently Deleted keeps memories for 30 days.
  • Edit anything — fix a transcript, rename a link, change tags.
  • Sharper search that finds what you meant.
  • Export everything in open formats.
  • Plus: recovered memories saved with Siri, Apple Watch voice notes now transcribed, and many fixes.

  Your memories, settings and subscription carry over untouched.
  ```
- [ ] **Phased release: ON** (7 days). Watch Crashes (Xcode → Organizer) and
      reviews daily. Pause the rollout if anything looks wrong.

---

## If something goes wrong after release

- **Pause** the phased release in App Store Connect (top of the version page).
- Every 2.0 install keeps a copy of the pre-update database at
  `App Group/Library/Backups/before-schema-2.0.0/`. If a user reports
  missing data, the Recovery screen's **Export a Copy** (or Settings →
  Export) gets you their data to restore from. The original files are never
  deleted by the upgrade.
