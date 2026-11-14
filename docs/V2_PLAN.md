# Orbit 2.0 — Plan

Status: **proposal, awaiting approval**. Nothing in the app has changed yet.
Written Nov 14, 2026, from a full read of the codebase, a data-safety audit and
competitor research.

---

## 1. The one rule: nobody loses anything

The update must be **boring for user data**: everything a user had in 1.x is
there in 2.0, on the first launch and every launch after. This section is
first because every other part of the plan has to obey it.

### What the audit found about data today

| # | Finding | Where | Impact today |
|---|---|---|---|
| D1 | **iCloud sync is not on.** Every store is created with `cloudKitDatabase: .none`, and the app has no iCloud entitlement. Memories exist only on the phone, plus the phone's own backup. | `ModelContainerFactory.swift:42-72`, `Orbit.entitlements` | Lose or replace the phone without a device backup, or delete the app, and everything is gone. Onboarding, Settings and the App Store description all say otherwise. |
| D2 | **If the database fails to open, the app silently uses a temporary in-memory store.** The user sees an empty Orbit, and anything captured then disappears on quit. | `OrbitApp.swift:38-40` | The scariest path for any update that touches the database. |
| D3 | **Siri / Shortcuts captures are saved into a different, hidden store** (`orbit-local` in the app sandbox) that the app never reads. | `CaptureTextIntent.swift:37` | Users who saved with Siri think it worked. The memories are still on their phone, just invisible. |
| D4 | **Apple Watch voice-note transcripts are thrown away.** The audio is kept. | `WatchSessionService.swift:83-88` | Watch memories can't be searched or summarized. |
| D5 | **A full swipe in Timeline deletes instantly and permanently.** No undo, no Recently Deleted. | `TimelineView.swift:101` | Accidental, permanent loss. |
| D6 | Memories saved from the Share extension and Siri are never enriched, and stay "pending" forever. | no launch sweep | Not titled, tagged or searchable. |
| D7 | Enrichment reads a memory, waits on the AI, then writes the whole record back, so changes made in between are lost. | `EnrichMemoryUseCase.swift:27-66` | Rare, but real, overwrites. |
| D8 | The Safari inbox can import the same clip twice (two drains at once). | `CaptureInboxService`, `OrbitApp.swift:117-127` | Duplicates. |

### How 2.0 protects data (layers — each one alone would prevent loss)

1. **Snapshot before anything changes.** On the first 2.0 launch, *before* the
   database is opened, copy the store files (`orbit.sqlite`, `-wal`, `-shm`)
   into `App Group/Library/Backups/pre-2.0/`. Media files are never moved or
   rewritten, only referenced. Keep the snapshot until the user has run 2.x
   successfully for 30 days. Never delete it automatically before then.
2. **Additive-only schema change.** `OrbitSchemaV2` only **adds** optional or
   defaulted fields (e.g. `deletedAt`, `editedAt`). Nothing is renamed,
   retyped or removed. An explicit lightweight `MigrationStage` V1→V2 in
   `OrbitMigrationPlan`.
3. **No more silent empty app (fixes D2).** If the store can't open, show a
   calm **Recovery screen**: "Your memories are safe on this iPhone. Orbit
   couldn't open them." Buttons: *Try again*, *Export a copy*, *Contact
   support*. The app never writes to a temporary store again.
4. **Migration tests on a real 1.x store.** CI builds a store with the
   **exact v1 schema**, fills it with every kind of memory, task, tag and
   insight (including sealed letters, voice notes, photos and
   Reminders-linked tasks), then opens it with 2.0 and checks every field
   survived. No 2.0 build ships unless this passes.
5. **Real-device upgrade rehearsal.** Install 1.0.x from the App Store on a
   test iPhone, use it for real, then install the 2.0 TestFlight build on
   top. TestFlight keeps the data. Check everything is there.
6. **Phased release.** App Store phased release over 7 days, which can be
   paused instantly if any report comes in.
7. **Never reset onboarding or settings.** Every existing `UserDefaults` key
   (`orbit.onboarding.completed`, theme, notification times, sync toggles,
   review counters…) is kept and read as-is. Existing users never see
   onboarding again and never get re-seeded welcome memories.

> **Honest note:** no engineer can promise "100%" about anything. What we can
> do is make loss require **every** layer above to fail at once — and in each
> failure case the original data is still on the phone, untouched.

### Data rescue (the first "wow" for existing users)

- **Recover Siri captures (D3):** on first launch, look for the hidden
  `orbit-local` store. If present, copy its memories and tasks into the main
  store (skipping any `id` that already exists), then keep the old file as a
  backup. Show: *"We found 4 memories you saved with Siri. They're in your
  timeline now."*
- **Recover Watch transcripts (D4):** queue every voice memory with audio but
  no transcript for background transcription, then enrichment.
- **Finish unfinished memories (D6):** sweep `pending`/`processing` memories at
  launch and enrich them.

---

## 2. iCloud sync (the biggest trust upgrade)

Users already believe Orbit syncs. 2.0 makes it true.

- **How:** the same store file, opened with `cloudKitDatabase: .private(
  "iCloud.com.joshgreen.orbit")`. SwiftData uploads the existing local
  records. Turning sync on **never deletes local data**. The schema was
  designed CloudKit-compatible from day one (all defaults, optional
  relationships, no unique constraints).
- **Graceful fallback:** if the CloudKit container can't open (not signed in
  to iCloud, iCloud full, misconfigured), Orbit opens the same store
  **local-only** and shows a quiet banner. It never shows an empty app.
- **Media:** photos and audio stay as local files in 2.0 (as today, and
  covered by device backup). New recordings are saved as compressed audio,
  about 10× smaller, so media sync can follow in 2.1 without filling people's
  iCloud. In 2.0, text, transcripts, tasks, tags, letters and AI metadata
  sync — the irreplaceable part.
- **Duplicates:** tags are merged by name on read and in a background
  clean-up, so two devices that both created "travel" show one tag.
- **Copy fixes:** "Delete account & data" now warns clearly that it deletes
  from iCloud on all devices. The App Store description, onboarding and
  Settings say exactly what is synced.
- **Release step you must do:** in CloudKit Console, **deploy the schema to
  Production** before releasing. If you forget, data stays safe locally, but
  sync won't work. This goes on the release checklist.

---

## 3. Fix what's broken

| Bug | Fix |
|---|---|
| Search returns almost everything once memories have embeddings (cosine mapped to 0…1, so unrelated items score about 0.5) | Use raw cosine with a real threshold. Lexical matches always rank above vague semantic ones. |
| Search loads every memory and its embedding on each keystroke | Predicate-driven fetches, plus cached embeddings off the main list path. |
| `fetchLimit` applied before sealed memories are filtered out (Recent widget goes blank behind a time capsule) | Filter inside the predicate. |
| "Delete account" leaves tasks, insights, media files, drafts and mirrors behind; deleting a memory leaves its media files | Complete wipe; delete media after the soft-delete window. |
| Share extension can run out of memory on large photos | ImageIO downsampling before encoding. |
| Ask uses up free quota even when the answer fails or is heuristic-only | Count usage only on a successful AI answer. |
| Home reloads 5 fetches one after another, twice per capture, and flashes "empty" | Parallel `async let`, keep content while refreshing, one fetch. |
| Capture button covers the last rows in Timeline, Tasks and Home | Proper bottom safe-area inset. |
| Onboarding says "nothing ever leaves your phone", but speech recognition can fall back to Apple's servers | Require on-device recognition where available, and make the copy exact. |
| Production RevenueCat key hard-coded with a "dev key" comment | Move to xcconfig/Info.plist. |

---

## 4. The 2.0 experience

Chosen from the competitor research. **No one combines a five-second brain
dump with an app that remembers and resurfaces.** ADHD dump apps sort captures
into tasks and forget them. Journals remember, but take effort. Orbit 2.0 owns
that gap.

### 4.1 What's New moment (existing users)
A single calm, full-screen sheet on the first 2.0 launch, shown once:
- "Your memories, now on all your devices" → turn on iCloud sync (one tap).
- "We found 4 memories you saved with Siri" (only if true).
- 3 headline features with one tap to try each.
- Pro users: "Thank you" line and nothing to buy. Free users: no paywall in
  this sheet.

### 4.2 Capture everywhere (under 2 seconds, from anywhere)
- **Control Center control** + **Lock Screen widget** + **Action Button**
  → voice capture.
- **Interactive widgets** (record / quick text right from the widget).
- **Live transcription while you talk**, using iOS 26's on-device
  SpeechAnalyzer. **Audio is saved first**, so a failed transcription never
  loses a recording (Voicenotes' and AudioPen's #1 complaint).
- Voice works even if speech permission is denied (saved as audio-only).
- Links without `https://` just work. Camera capture (the Lock Screen camera
  extension) is re-enabled.
- **Screenshot text is read automatically** (OCR is already in the code, but
  never called).

### 4.3 Siri and Apple Intelligence
- **App Entities** for memories and tasks, so Siri, Spotlight and Shortcuts
  can find and open them ("Siri, what did I save about the plumber?").
- Intents: Capture, Ask Orbit, Today's Recap, Add Task, Open On This Day.
- On iOS 27, adopt the new semantic-index schemas (availability-gated, so iOS
  26 users are unaffected). This is the featuring hook Apple is promoting this
  year.
- **Apple Intelligence status** shown gently in Settings. Devices without it
  get honest "basic mode" labels and don't spend quota.

### 4.4 Find anything (not chat-only)
- Fixed search relevance, filters (type, person, place, date), and search
  that highlights the exact match.
- Ask Orbit answers cite their source memories (tap to open).

### 4.5 Edit and control
- **Edit memories** (text, title, tags). The use case exists but is unused.
- **Add tasks manually.**
- **Recently Deleted** (30 days) + **Undo** toast after any delete.
- **Export everything** (Markdown + JSON + media, as a ZIP to Files). "Your
  memories are yours" — trust that converts privacy-minded buyers.
- **Retry** button on failed AI processing.

### 4.6 Look and feel
- Adopt **iOS 26 Liquid Glass** for the tab bar, capture button and sheets
  (system components first), following CLAUDE.md: solid surfaces for content,
  glass only for chrome.
- Shame-free design throughout: no streak punishment, no unread counts.
- Accessibility pass: labels on icon-only buttons (Watch included), Dynamic
  Type on share cards and Live Activities, Reduce Motion.

### 4.7 Growth and revenue (new users only)
- **End-of-onboarding paywall** with a clear **"Not now"** — for new installs
  only. Existing users never see onboarding again.
- **Trial:** test 14 days on yearly (research: a 1-week trial is short for an
  app whose value builds over time).
- **Review prompt** after real value moments (5th capture, a successful Ask,
  a resurfaced memory), not only after the 3rd recap.
- **Existing subscribers and lifetime buyers keep everything at their
  current price.** Any price test applies to new purchases only, via
  RevenueCat offerings.

---

## 5. Not in 2.0 (planned for 2.1+)

| Item | Why later |
|---|---|
| Spanish / Portuguese app UI | Needs every UI string moved into String Catalogs across 13 packages. Start the groundwork in 2.0; translate in 2.1. The App Store listing (Phase 0) can be localized now. |
| iPad + Mac | Layout work after the 2.0 foundations settle. |
| Media sync (photos/audio via iCloud) | After compressed audio has been in place for a release. |
| Memory graph, Shared Orbits | Big features; better on a stable sync foundation. |

---

## 6. How we build it without breaking anything

**Constraint:** this cloud environment has no Xcode or Swift compiler. I can
write code, but can't compile or run it here.

**Solution: GitHub Actions on a macOS runner** builds the app and runs every
test on each push to the branch. I read the results and fix failures before
asking you to test. The migration tests (section 1, layer 4) run there.

**Order of work** — each step is its own commit, compiled and tested by CI:

1. CI workflow + migration test harness (v1 fixture store).
2. Data-safety foundation: snapshot, Recovery screen, schema V2 + stage,
   Siri-store rescue, enrichment sweep, Watch transcript fix.
3. Bug fixes (section 3).
4. Recently Deleted + Undo, Export.
5. iCloud sync with local fallback.
6. Edit memories, manual tasks.
7. Capture everywhere (controls, widgets, live transcription, OCR).
8. Siri / App Entities.
9. Liquid Glass + accessibility pass.
10. What's New sheet, onboarding paywall, review prompt.
11. Version 2.0, TestFlight, upgrade rehearsal on a real device, release.

You test on your iPhone at the TestFlight stage. I'll give you a checklist,
including the "install 1.x, then upgrade" rehearsal.

---

## 7. Release checklist (2.0)

- [ ] CI green: build + all tests, including the v1→v2 migration test.
- [ ] CloudKit Console: schema **deployed to Production**.
- [ ] iCloud capability + container `iCloud.com.joshgreen.orbit` enabled on
      the App ID (developer.apple.com → Identifiers).
- [ ] TestFlight upgrade rehearsal on a real device with real 1.x data:
      memories, voice notes, photos, letters, tasks, settings all present.
- [ ] Fresh-install test: onboarding, paywall "Not now", first capture.
- [ ] Sync test with two devices (or delete and reinstall + restore from iCloud).
- [ ] App Store metadata updated to describe sync accurately.
- [ ] Phased release ON. Watch crash reports and reviews daily for 7 days.
