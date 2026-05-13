# Orbit — App Store Privacy Nutrition Label

A reference for filling out App Store Connect → App Privacy. Based on a
code-level audit of every data flow as of the current branch.

## Headline

**Recommended label: "Data Not Linked to You" — Audio Data only.**
**Everything else: Data Not Collected.**

Orbit has no backend, no analytics SDKs, no third-party trackers, and no
cloud sync. The only path on which user-provided data leaves the device
to a non-Apple server is the **server-side speech-recognition fallback**
in `SpeechTranscriber.swift` (line 51), where Apple's framework — not
Orbit — receives the audio when on-device recognition is unavailable.
Apple is the data processor; Orbit never sees the audio after the
hand-off. Per Apple's nutrition-label guidance you still disclose this.

If you decide to remove the server fallback (see "Open Question"
below), the label becomes **"Data Not Collected"** across the board —
the strongest privacy posture Apple offers.

## App Store Connect declarations

In the App Privacy form, for each section, click "Add Data Type" and
toggle as below.

### Data Used to Track You
**None.** No advertising identifiers, no cross-app/cross-site tracking,
no third-party SDKs that do this on Orbit's behalf.

### Data Linked to You
**None.** Orbit doesn't transmit user content to Orbit-controlled
servers. Sign In with Apple gives Orbit only a stable user identifier
that lives in the device Keychain and never leaves.

### Data Not Linked to You
**Audio Data** — declare with the following:
- **Purpose**: App Functionality
- **Linked to user identity?** No
- **Used for tracking?** No
- **Justification (for App Review if questioned)**: "Voice notes are
  transcribed using Apple's `SFSpeechRecognizer`. We request
  `requiresOnDeviceRecognition = true` first; the framework falls back
  to Apple's server-side recognition only when on-device is
  unavailable. The audio stream is delivered by Apple's API directly
  to Apple's recognition service. Orbit does not retain, transmit, or
  process the audio outside this Apple-managed flow."

That's the only one. Skip every other category — they're all
"Data Not Collected" because the data never reaches Orbit or any
third party.

### Data Not Collected (the rest, for confidence)

| Category | Reason it's not collected |
|---|---|
| Contact Info (name, email, phone, address) | SiwA-provided name/email stays in Keychain, never transmitted. |
| Health & Fitness | HealthKit reads (sleep, steps) populate Recap on-device only. |
| Financial Info | StoreKit transactions are Apple-mediated; Orbit never sees card data. |
| Location | Orbit never asks for location. |
| Sensitive Info | n/a. |
| Contacts | Orbit never asks. |
| User Content — Emails or Text Messages | Text captures are local-only. |
| User Content — Photos or Videos | Photos/screenshots are local-only. |
| User Content — Gameplay Content | n/a. |
| User Content — Customer Support | n/a. |
| Browsing / Search History | Search runs entirely on-device. |
| Identifiers — User ID | SiwA identifier stays in Keychain only. |
| Identifiers — Device ID | Not collected. |
| Purchases | Apple-mediated. |
| Usage Data | No analytics SDK. |
| Diagnostics | No crash reporter, no third-party telemetry. |
| Other Data | n/a. |

## Open question — speech-recognition fallback

`SpeechTranscriber.transcribe(fileAt:)` (Packages/OrbitMedia/...) calls
`runRecognition(url:, requireOnDevice: true)` first, then on failure
calls `runRecognition(url:, requireOnDevice: false)`. The fallback
sends the audio file to Apple's recognition service.

Three options, ordered by my recommendation:

1. **Disclose Audio Data** (current recommendation above) and keep the
   fallback. Best transcription reliability, honest disclosure, label
   stays clean.

2. **Force on-device only** — drop the fallback. The recap label flips
   to a flawless "Data Not Collected." Possible regressions: users on
   languages without on-device support get no transcription;
   first-launch transcription fails until Apple's on-device model is
   downloaded. The current `NSSpeechRecognitionUsageDescription`
   string says "on-device" — this option makes it true.

3. **User-controlled** — add a "Send to Apple for better transcription"
   toggle in Settings, default off. Best of both worlds but a small UI
   addition. Worth doing if you ever expand to languages where
   on-device support is shaky.

The current usage string at `project.yml:89`
("transcribes your voice notes on-device") is **technically
inaccurate** if option 1 is chosen — consider amending to
"transcribes your voice notes (on-device whenever possible)."

## Permission usage strings — quick check

All in `project.yml`. Currently correct and on-brand:
- `NSMicrophoneUsageDescription` — accurate.
- `NSSpeechRecognitionUsageDescription` — see open question above;
  the "on-device" claim is conditional.
- `NSPhotoLibraryUsageDescription` — accurate.
- `NSCameraUsageDescription` — accurate.
- `NSRemindersFullAccessUsageDescription` — accurate (mirror sync only).
- `NSCalendarsFullAccessUsageDescription` — accurate.
- `NSHealthShareUsageDescription` — accurate; emphasizes "privately"
  and "reads" only.

## What changes if Orbit adds backend services later

The nutrition label will need to expand if any of these ship:

| Future addition | New disclosure required |
|---|---|
| CloudKit sync of memories | Most user content categories flip to "Linked to You" (CloudKit is tied to the user's Apple ID). |
| Cloud AI (OpenAI, Anthropic) on capture content | Text / audio / image content gets disclosed under App Functionality, Linked to You if associated with the user account. |
| Third-party analytics (Firebase, Sentry, Amplitude, etc.) | Usage Data and Diagnostics get disclosed. Tracking determination depends on the SDK. |
| Crash reporting that includes user identifiers | Diagnostics → Linked to You. |
| Email digests / push notifications via a backend | Email Address gets disclosed if Orbit servers receive it. |
| Sharing memories to friends/social | Content + identifiers get disclosed. |

If/when any of those land, update this doc *before* the App Store
submission so the form matches reality.

## Sources

This doc reflects the code in branch `claude/plan-app-store-fixes-hUPNT`.
Audit was code-level across:

- All capture flows (text, voice, photo, screenshot, link).
- AI enrichment pipeline (`FoundationModelsAdapter`, `CloudAIService`
  placeholder, `EmbeddingService`).
- Persistence (`SwiftDataMemoryRepository`, App Group container,
  Documents/Orbit/media).
- Auth (`AccountService`, Keychain reads, no remote credential check
  beyond Apple's own).
- HealthKit, EventKit (Calendar/Reminders).
- Watch app, Share Extension, Lock-screen camera extension, Widgets.
- `Package.swift` for third-party dependencies (none beyond Apple
  frameworks).

If those areas materially change, re-run the audit before submission.
