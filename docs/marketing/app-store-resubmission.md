# App Store resubmission — what to put where

Six fields in App Store Connect that need real content during a
resubmission. Copy-ready for each below.

If this is your **first submission**, fill them all in fresh. If
this is a **resubmission after a rejection**, the most important
field is **App Review Information → Notes** — that's where you
explain to Apple's reviewers what you changed.

---

## 1. App Information (one-time, app-level)

`App Store Connect → My Apps → Orbit → App Information`

Update once. Most fields persist across versions.

| Field | What to enter |
|---|---|
| Name | `Orbit — AI Second Brain` |
| Subtitle | `Journal, voice notes & recap` |
| Privacy Policy URL | `https://orbitbrain2.netlify.app/privacy` |
| Category — Primary | Productivity |
| Category — Secondary | Lifestyle |
| Content Rights | "Does this app contain, show, or access third-party content?" → **No** (Orbit only shows user-captured content) |

Keywords field is per-version, not here — see section 2.

---

## 2. Version Information (per-version metadata)

`App Store Connect → My Apps → Orbit → [your version] → App Store tab`

### Promotional Text (170 char max — editable without resubmission)

Use this as the always-on "first line above the description":

```
Capture life as it happens. Orbit organizes the rest — quietly, on-device, with Apple Intelligence.
```

(98 / 170 chars used.)

### Description (4000 char max)

The full one from `docs/marketing/app-store-listing.md`. Paste the whole "Description" block from that file. Starts with:

```
Orbit is a second brain for the things you don't want to forget…
```

### Keywords (100 char max, comma-separated, no spaces between)

```
memory,memo,gratitude,mood,habit,tracker,reflect,mindful,wellness,thoughts,daily,captures,lifelog
```

(97 / 100 chars. Don't add words already in the name or subtitle — Apple indexes those automatically.)

### Support URL

```
https://orbitbrain2.netlify.app/support
```

### Marketing URL (optional)

```
https://orbitbrain2.netlify.app
```

### What's New in This Version (4000 char max)

This is what users see as the "release notes" when the update lands.

**For v1.0 (first launch):**

```
Welcome to Orbit.

This is our first release — a calm second brain built around Apple Intelligence, designed to feel native, fast, and quiet.

Capture text, voice, photos, and links into one timeline. Orbit organizes the rest on-device. Daily Recap reflects your day back to you each evening. Ask Orbit lets you chat with your own memories. Your past resurfaces gently, on cue.

Everything works on-device first. Your memories stay yours.
```

**For v1.0.1 (if you're resubmitting after a rejection):**

```
This release addresses feedback from the App Review team and ships small refinements to onboarding, accessibility, and performance across the experience.

Thank you for trying Orbit. If you run into anything, please reach us at support@orbitbrain2.netlify.app — we read every message.
```

**For v1.1 (after launch, real feature update):**

```
This update brings:
• [feature shipped]
• [improvement]
• Bug fixes and polish across the experience.

Thank you for trying Orbit. Your feedback shapes every release.
```

---

## 3. Screenshots

`App Store Connect → Orbit → [version] → App Store tab → Screenshots section`

Upload to the **iPhone 6.7" Display** slot. Apple auto-derives other device sizes.

Drag all 10 PNGs in at once. Filename order determines listing order:

```
01-problem.png
02-solution-shape.png
03-ai-magic.png
04-daily-recap.png
05-ask-orbit.png
06-past-on-cue.png
07-tasks-find-themselves.png
08-ecosystem.png
09-share-card.png
10-privacy.png
```

**App Preview** (optional video) — skip for v1; revisit post-launch.

---

## 4. App Privacy (Privacy Nutrition Labels)

`App Store Connect → Orbit → App Privacy`

These persist between versions but need to be filled in once. From
`app-store-listing.md`, the truthful answer set for Orbit today:

### Data Linked to You

Required because of Sign in with Apple:

- **Identifiers** → User ID (Apple's `sub` claim)
- **Contact Info** → Name, Email Address (only if the user shares — Hide My Email counts)

For each: select **App Functionality** as the use case. Mark
**Tracking: No**.

### Data Not Collected by Us

Everything else lives on-device / in user-owned iCloud:

- Memories (text, voice, photos, links, locations)
- HealthKit (sleep + steps — read on demand, not stored)
- Calendar / Reminders (read/write for sync, not duplicated)

> Note: iCloud sync via CloudKit is **user-owned data**. Apple holds
> it encrypted on the user's behalf; Orbit (the company) never sees
> it. This is **not** data collection for the Privacy Nutrition
> Label per Apple's own definition.

### Tracking

Mark **Orbit does not track users**. Disable IDFA / tracking
permission entirely.

---

## 5. App Review Information (this is the critical one)

`App Store Connect → Orbit → [version] → App Information → App Review Information`

This is where most rejections happen — and where good notes prevent
them. Apple's reviewer reads this before testing your app.

### Sign-In Information

Sign in with Apple is the only auth, and reviewers can use their
own Apple ID:

- **Username**: leave blank
- **Password**: leave blank
- **Check**: "Sign-in not required" → **Yes** (Orbit works in guest mode too)

If asked for demo credentials, add a note (in the Notes field below)
that reviewers can sign in with their own Apple ID via Sign in with
Apple, or proceed as a guest from the welcome flow.

### Contact Information

- **First Name**: Josh
- **Last Name**: Green
- **Phone Number**: your real one (Apple may call about rejections)
- **Email Address**: support@orbitbrain2.netlify.app (or your real address)

### Notes (the field that prevents rejections — 4000 char max)

For a **first submission**, paste this:

```
Hello, and thank you for reviewing Orbit.

A few notes that will help your testing:

ABOUT THE APP
Orbit is a calm "second brain" — users capture text notes, voice memos, photos, links, and locations into one timeline. Apple Intelligence (on-device, via the Foundation Models framework) generates titles, tags, summaries, and conversational answers across the user's own captures. No data leaves the device. There are no third-party analytics SDKs, no advertising IDs, and no cross-app tracking.

GETTING IN
- Sign in with Apple is available on the welcome flow; you can sign in with your own Apple ID.
- "Continue as guest" is also offered if you'd prefer not to sign in. All features work in guest mode except cross-device sync.

DEMO CONTENT
The app ships clean on first install. If you'd like to see Orbit with realistic content (Daily Recap, Ask Orbit answers, etc.), you can capture a few memories using the + button on any tab — text, voice, photos, or links. Apple Intelligence will tag and summarize automatically within ~10 seconds of capture.

PERMISSIONS
We ask for two permissions during onboarding (both optional):
- Notifications — for the Daily Recap chime at the user's chosen time
- Microphone — for voice memo capture

Three more permissions are asked just-in-time when the user first reaches the relevant feature:
- Speech Recognition — when transcribing a voice memo
- Photos — when attaching an image
- HealthKit (Sleep + Steps) — when enabling the optional Health integration in Settings
- Reminders / Calendar — when toggling the optional sync features in Settings

Each permission flow respects the user's choice and degrades gracefully if denied.

APPLE INTELLIGENCE
Orbit's AI surfaces (Daily Recap narrative, Ask Orbit answers, auto-tagging, share-card summaries) require an Apple Intelligence-capable device (iPhone 15 Pro / 16 series or later running iOS 18.1+). On older devices, Orbit falls back to lightweight on-device heuristics so the app still functions — you may see less elaborate categorization there.

ACCOUNT DELETION (5.1.1(v))
Per Apple's account deletion requirement, users can fully delete their account and all associated data via Settings → Account → Delete account. The action wipes every captured memory, signs the user out, ends any active subscription, and resets the app to its first-launch state. The path is reachable from the in-app Settings without contacting support.

SUBSCRIPTIONS
Orbit Pro is sold via StoreKit 2 in-app purchase. There are two subscription products (monthly and annual). The Pro entitlement unlocks unlimited captures and the AI surfaces. Free-tier users can capture up to N memories per month and use a limited set of features.

EXTENSIONS BUNDLED
The app ships with these extensions (all opt-in or contextual):
- Share extension (system Share Sheet → Orbit)
- Home Screen widget
- Safari Web Extension (for clipping pages into Orbit)
- Apple Watch companion app (voice memos)
- Lock Screen camera capture extension (LockedCameraCaptureExtension)
- Live Activity for active voice recordings (Dynamic Island)

PRIVACY POLICY AND TERMS
Both are hosted at orbitbrain2.netlify.app. Direct links:
- https://orbitbrain2.netlify.app/privacy
- https://orbitbrain2.netlify.app/terms
- https://orbitbrain2.netlify.app/support

Reach me at support@orbitbrain2.netlify.app if anything is unclear or doesn't behave as expected during testing. I appreciate your time.

— Josh Green
```

For a **resubmission after rejection**, replace the opening paragraph with the specific change list. Example:

```
Hello, and thank you for re-reviewing Orbit.

This resubmission addresses the feedback from your previous review:

1. [Specific rejection reason 1] → I changed [X] by doing [Y]. You can verify by [step-by-step path].
2. [Specific rejection reason 2] → I changed [X] by doing [Y]. You can verify by [step-by-step path].

The rest of the app is unchanged from the previous build.

[Then keep the rest of the notes above as background context.]
```

The specificity is what gets resubmissions approved fast. Apple reviewers triage thousands of apps a day — telling them exactly what changed + where to verify it lets them re-approve in one pass.

### Attachments (optional)

If anything is hard to discover by reviewing alone (e.g., a hidden flow), upload a short screen recording. Especially useful if the rejection was a "can't find feature X" call.

---

## 6. Resolution Center (only if responding to a previous rejection)

`App Store Connect → Orbit → Resolution Center` (only visible if there's an open rejection)

Reply to the reviewer's message **before** submitting the new build. Match the tone to the rejection: short, factual, addressing each point.

**Template:**

```
Hello,

Thank you for the detailed feedback on the previous build. I've addressed each of the points raised:

1. [Their concern 1] — [What I changed]. You can verify this by [path or steps].
2. [Their concern 2] — [What I changed]. You can verify this by [path or steps].

I've also added more detail to the App Review Notes in the new submission to help with verification.

If anything is still unclear, I'm happy to provide a screen recording or further explanation. Thanks again for your time.

— Josh
```

After sending the reply, submit the new build. The reviewer typically picks up your resubmission within 24–48 hours and references your Resolution Center reply when re-evaluating.

---

## Submission flow summary

For a clean resubmission:

```
1. App Information         → update if any (mostly stays the same)
2. App Privacy             → already set, verify it still matches reality
3. New version
   ├─ Promotional Text     → paste from section 2
   ├─ Description          → paste from app-store-listing.md
   ├─ Keywords             → paste from section 2
   ├─ Support URL          → orbitbrain2.netlify.app/support
   ├─ Marketing URL        → orbitbrain2.netlify.app
   ├─ What's New           → paste from section 2 (pick the matching variant)
   ├─ Screenshots          → upload the 10 PNGs
   └─ Build                → uploaded via Xcode → Archive → Distribute App
4. App Review Information
   ├─ Sign-in              → not required (guest path works)
   ├─ Contact              → your info
   └─ Notes                → paste from section 5 (pick the matching variant)
5. (If rejected previously)
   └─ Resolution Center    → reply with the change list before submitting
6. Submit for Review
```

Apple's typical turnaround is 24–48 hours. You'll get an email when
the review completes, then again when the app is live in the store.

---

## Common rejection causes (so you can avoid them)

| Reason | Pre-emptive fix |
|---|---|
| 3.1.2(a) — Terms of Use (EULA) link missing from description | Always include the closing block in the description with a functional `https://...` link to the Terms of Use. Apple's bot scans the description text for it. Standalone Privacy Policy URL field is not enough. |
| 5.1.1(v) — no account deletion | We have this — Settings → Account → Delete account |
| 5.1.1 — privacy policy missing | Privacy URL is set to your live Netlify route |
| 4.0 — design feels unfinished | Polish pass complete; empty states are designed, not blank |
| 2.1 — crashes on launch | Pre-flight: archive a Release build, install on a real device, verify launch in airplane mode |
| 2.3.7 — keywords misuse | We use only niche terms not duplicating name/subtitle |
| 2.3.10 — extraneous content | All visible content references real app behavior |
| 5.1.1 — subscription transparency | The paywall shows price, renewal terms, and a cancel-anytime line before purchase |

---

## After submission

While you're waiting:

- **Don't** withdraw and resubmit if you spot a typo unless the change is critical. Each resubmission resets the review queue. Small text fixes can usually wait for v1.0.1.
- **Do** monitor `support@orbitbrain2.netlify.app` — Apple reviewers occasionally email if they need clarification.
- **Do** prep a launch-day post for Twitter / Threads / LinkedIn / Hacker News so you can ship the announcement the moment the email arrives.
