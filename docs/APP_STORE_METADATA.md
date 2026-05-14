# Orbit — App Store Submission Reference

Two halves: (1) **Website audit** — exact text changes for the four
live pages before App Review can see them; (2) **App Store Connect
metadata** — name, subtitle, promo text, description, keywords,
screenshot story. Anything here can be revised once you've seen it,
but it's a finished draft you can paste in if you want to move fast.

The website lives at `docs/marketing/website/` on branch
`claude/ios-app-architecture-p5jNu`. Once you merge or cherry-pick
the fixes below, the Netlify deploy picks them up automatically.

## Part 1 — Website audit

### 🔴 Must fix before submission

These are factually wrong or template placeholders. App Review will
click these links. Mismatches between the privacy policy and the
nutrition-label declaration are a classic rejection reason.

#### All pages — fill in placeholders

| File | Placeholder | Replace with |
|---|---|---|
| `privacy.html`, `terms.html` | `{{ launch date }}` (×2 each) | Your actual effective + last-updated date, e.g. `May 13, 2026`. |
| `privacy.html`, `terms.html` | `{{ your legal name or company }}` | Your full legal name (or LLC name if you've filed one). The App Store seller name should match this. |
| `terms.html` | `{{ your jurisdiction }}` | The U.S. state (or country) whose laws govern. Most solo devs pick their home state, e.g. `the State of California`. |

#### `support.html` — iOS version is wrong

**Q6 "Which iPhones run the AI features?"** currently reads:

> "…require an iPhone with Apple Intelligence — iPhone 15 Pro / Pro
> Max, iPhone 16 lineup, or newer, running **iOS 18.1 or later**."

The project's actual deployment target is **iOS 26.0**
(`project.yml:13`). The whole app won't install on iOS 18.x — the
"AI features need iOS 18.1+" framing is left over from an earlier
version of the project. Replace with:

> "Orbit requires **iPhone running iOS 26 or later**. The AI surfaces
> (Daily Recap, Ask Orbit, auto-summaries) use Apple
> Intelligence, which is available on the iPhone 15 Pro lineup,
> every iPhone 16 model, and newer. On supported devices everything
> happens on-device; on older models you'll get lightweight
> heuristic versions of the same features."

(Sanity-check the device list against Apple's current Apple
Intelligence compatibility matrix when you publish — it may be
broader by your submission date.)

#### `support.html` — iPad reference is wrong

**Q1 "Where are my memories stored?"** ends with:

> "…you can pick up across iPhone, **iPad**, and Apple Watch."

Orbit v1 is **iPhone-only and portrait-locked**
(`TARGETED_DEVICE_FAMILY = 1`, `UISupportedInterfaceOrientations` =
Portrait only). Replace with:

> "…so you can pick up between iPhone and Apple Watch. (Orbit v1 is
> iPhone-only; iPad support is on the roadmap.)"

#### `privacy.html` + `support.html` — speech recognition fallback

Both pages claim speech recognition is on-device only:

- `privacy.html` (Section 3, "AI Processing"): "No network calls
  are made to AI services." ← speech is technically an AI service
  on the fallback path.
- `support.html` (Q4, "Why didn't my voice note transcribe"):
  "Orbit transcribes voice notes on-device using Apple's Speech
  Recognition." ← only true on the primary path.

Per the privacy-nutrition-label audit, `SpeechTranscriber.swift:51`
falls back to Apple's server-side speech recognition when on-device
fails. The fix depends on which option you took there:

- **If you keep the fallback** (audio data declared in nutrition
  label): amend privacy Section 3 to add:

  > "Voice transcription: Orbit requests on-device speech
  > recognition first. When that's unavailable (older devices,
  > unsupported languages, model not yet downloaded), Apple's
  > framework may fall back to Apple's hosted speech-recognition
  > service. The audio is processed by Apple, not Orbit — we never
  > receive it. You can confirm or disable this in
  > Settings → Orbit → Speech Recognition."

  And amend support Q4 to read:

  > "Orbit transcribes voice notes using Apple's Speech Recognition.
  > It runs on-device whenever your iPhone supports it; if not, the
  > audio is processed by Apple's recognition service. iOS will ask
  > for permission the first time you record. If you previously
  > declined, go to iOS Settings → Orbit → Speech Recognition and
  > turn it on."

- **If you force on-device only**: no privacy-page change required;
  support Q4 stays accurate.

#### `index.html` — "End-to-end iCloud"

The privacy table on the homepage says:

> "Your data lives **on your iPhone, and in your private iCloud.**
> We never see it." (accurate)

But the feature-grid card "Private by design" says:

> "On-device AI. **End-to-end iCloud.** No analytics, no ads, no
> third-party SDKs."

iCloud is encrypted in transit and at rest by default, but only
*end-to-end encrypted* when the user enables Advanced Data
Protection. Most users have not. The "End-to-end iCloud" phrasing
will read to a savvy reviewer as overclaiming. Suggested replacement:

> "On-device AI. Private iCloud. No analytics, no ads, no
> third-party SDKs."

### 🟡 Worth tightening

These aren't wrong, but they don't match the production decisions
on this branch.

- `privacy.html` "Your Rights" section: "Delete a single memory —
  **long-press, then Delete**." Accurate on Home, Search, and On
  This Day after our delete-consistency pass. On Timeline you swipe
  instead. Suggest:

  > "Delete a single memory — long-press the card (or swipe left
  > on Timeline) and tap Delete."

- `index.html` end-CTA and hero link to
  `https://apps.apple.com/app/orbit/id6769115384`
  (App Store ID assigned by Apple in App Store Connect).
  `docs/marketing/landing.md` uses the same URL.

- The contact email **`support@orbitbrain2.netlify.app`** uses a
  Netlify subdomain that won't deliver mail. Apple's submission
  form *will* try sending to your support email during review.
  Either:
  - Set up a real mailbox at a domain you control (recommended —
    e.g. `support@orbit.app` if you own that, or `orbitapp@gmail.com`
    while you sort out the domain), and update across all four pages
    + the in-app `Settings → About → Contact Support` link.
  - Or use a forwarding service (Cloudflare Email Routing, Fastmail
    alias, etc.) so the address resolves to an inbox you check.

- `terms.html` Section 3 (Subscriptions): "Payment is charged…at
  the end of each **free trial (if any)**…" — Orbit *does* have a
  free trial (7-day on the yearly plan, per our paywall work).
  Strengthen by replacing "(if any)" with the concrete fact:

  > "Orbit Pro is offered as a yearly subscription with a 7-day free
  > trial for new subscribers. After the trial, payment is charged
  > to your Apple ID at the start of each yearly renewal period.
  > Subscriptions renew automatically unless cancelled at least 24
  > hours before the current period ends."

- `terms.html` Section 9 (Limitation of Liability): the **USD 50**
  cap is a placeholder common in templates. Confirm with your own
  judgment / counsel — not legal advice from me; flagging only.

### ✓ Accurate as-is

For reference, these claims were verified against the codebase:

- "Apple Intelligence handles every prompt locally" (homepage privacy
  table + privacy Section 3) — verified against
  `FoundationModelsAdapter`. `CloudAIService` is a placeholder that
  throws `aiUnavailable`.
- "No analytics SDKs. No advertising IDs. No cross-app tracking"
  (homepage + privacy) — verified; `Package.swift` lists only
  first-party Apple frameworks.
- "Sign In with Apple…we use this only to identify you across
  launches and devices" — verified against `AccountService` +
  Keychain.
- "Capture from the Lock Screen", "Speak into your Watch", "Share
  with one tap" — all verified (Lock Screen Camera Extension,
  WatchApp/, Share Extension exist).
- Safari Extension chip — verified (`Extensions/SafariExtension/`
  is real, with `SafariWebExtensionHandler`).
- "Settings → Account → Delete account wipes the whole experience"
  — verified (`AppEnvironment.wipeAccountAndData`).
- StoreKit subscription handling — verified.

## Part 2 — App Store Connect metadata

Below are paste-ready drafts. Apple's character limits are noted.

### App Name (max 30)

**`Orbit`** (5/30)

Clean. Don't pad it with "— Memory Journal" or similar — short app
names rank better and look more confident on the home screen.

### Subtitle (max 30)

**`Memories, quietly organized.`** (28/30)

The subtitle shows beneath the app name in search results and on the
product page. This one captures the AI-organizes positioning and the
calm voice in 28 chars.

Alternatives if you want something different:
- `A calm second brain.` (20)
- `Your second brain on iPhone.` (28)
- `Memories find their orbit.` (26) — matches the homepage hero

### Promotional Text (max 170)

This is editable any time without re-review. Use it for announcements
or seasonal positioning.

**Default:**

> A calm second brain that captures text, voice, photos, and links —
> then quietly organizes everything with Apple Intelligence, on your
> device. (149/170)

### Description (max 4000)

```
Orbit is a second brain for the things you don't want to forget —
the half-formed idea on a walk, the restaurant a friend keeps
recommending, the thought that wakes you up at 3am.

Capture it once. Orbit organizes the rest, quietly.

— ONE TIMELINE FOR EVERYTHING
Text, voice notes, photos, screenshots, links, even a place. One tap
to save. Everything lives in a single chronological timeline.

— AI THAT HIDES ITSELF
Apple Intelligence reads your captures on-device, then writes the
titles, the tags, the summaries, and the categories. You spend zero
seconds organizing. Your captures never leave your phone.

— DAILY RECAP
Every evening, Orbit reads the day's captures and writes a
one-paragraph reflection — never a list, never a metric. The moments
worth revisiting are linked underneath.

— ASK ORBIT
Type a question the way you'd ask a friend. "What did Pamela say
last weekend?" "What was that book Mateo recommended?" Orbit
answers from your own captures and links you back to the moments
it pulled from.

— ON THIS DAY · YEAR IN REVIEW
Orbit resurfaces your past at the right moment. Time-capsule letters
to your future self deliver themselves on the date you choose.

— NATIVE ON EVERY SURFACE
Capture from the Lock Screen camera. Speak into your Apple Watch.
Search in Spotlight. Share with one tap from any app. Your tasks
sync to iOS Reminders. Your sleep arrives in your Daily Recap.

— PRIVATE BY DESIGN
- On-device AI via Apple Intelligence
- Stored on your iPhone and your private iCloud
- No analytics SDKs, no advertising IDs, no third-party trackers
- Sign in with Apple, or use as a guest

— ORBIT PRO
A yearly subscription unlocks unlimited Daily Recaps, unlimited Ask
Orbit, long-form voice notes, and your full Year in Review.
Free to try for 7 days.

Subscriptions auto-renew unless cancelled 24 hours before the period
ends. Manage in iPhone Settings → Apple ID → Subscriptions.

Privacy Policy: https://orbitbrain2.netlify.app/privacy
Terms of Use: https://orbitbrain2.netlify.app/terms

Requires iPhone running iOS 26 or later. AI features require Apple
Intelligence support.
```

Approx 1,890/4,000 — comfortably under. Avoid the temptation to add
more; shorter App Store descriptions perform better.

### Keywords (max 100, comma-separated, no spaces between)

**`second brain,memory,notes,voice memo,journal,ai,diary,reminders,capture,recap,apple intelligence`**

(100/100 — verified)

Notes on choices:
- "second brain" is the conceptual keyword most likely to surface
  Orbit to people who already know the category (Tiago Forte
  audience).
- "ai" and "apple intelligence" both included because the
  search-completion paths are different.
- "notes" and "journal" hit the two adjacent app categories
  Orbit competes against.
- "voice memo" matches Apple's first-party app — high search volume.
- Don't include the app name "Orbit" (Apple indexes it automatically
  from the App Name field — duplicate is a waste of characters).

### Category

- **Primary**: Productivity
- **Secondary**: Lifestyle (or Health & Fitness, if you want to
  emphasize the gratitude / reflection angle)

### Age Rating

- **4+** unless the user-generated content (notes, voice) is rated
  separately. UGC is between the user and themselves in Orbit; not
  rated. Apple's questionnaire will ask about UGC moderation — since
  there's no social/share-out, this stays 4+.

### Pricing & subscription disclosure

For App Store Connect's "App Information" → "Subscriptions" group,
the in-review form will want:

- Product ID: matches what's in `Configuration.storekit`
- Trial: 7 days
- Renewal: Yearly
- Display name: Orbit Pro
- Description (max 45): "Unlimited Recap, Ask Orbit, long voice, full Year in Review."

Also: the **privacy URL** and **terms URL** must be set in App Store
Connect → App Information. Use the orbitbrain2.netlify.app paths
above for now; update if the domain changes.

### Support URL

`https://orbitbrain2.netlify.app/support` — required field.

### Marketing URL (optional)

`https://orbitbrain2.netlify.app/` — optional but recommended.

## Part 3 — Screenshot story (5–10 frames)

Required: 6.9" iPhone Pro Max screenshots (1320×2868 or 2868×1320).
You can supply just the largest size and Apple downsamples for
older devices, since Orbit is portrait-only.

The story should land in three beats: **here's the surface →
here's what makes it different → here's why it feels good**. Six
frames is plenty.

| # | Surface | What it shows | Caption |
|---|---|---|---|
| 1 | Timeline (3-4 memories) | The default landing — varied content (one voice card, one text, one link) showing the eyebrow tags AI auto-generated. | "Your second brain. One timeline." |
| 2 | Capture sheet, voice tab mid-recording | Voice waveform, live transcript appearing underneath. | "Speak it. Orbit transcribes on your phone." |
| 3 | Memory Detail | A voice note opened, showing transcript + AI summary + auto-tags. | "Apple Intelligence writes the titles, the tags, the summaries." |
| 4 | Daily Recap | A finished recap with one paragraph of reflective prose + linked highlights below. | "A day, read back to you. Each evening." |
| 5 | Ask Orbit, conversation mid-flow | A question typed, an answer rendered, source memory cards linked underneath. | "Ask anything. Orbit answers from your own memories." |
| 6 | Year in Review — Pro showcase | Editorial layout, big serif numbers, a memory-rain animation paused on a frame. | "Your year, the way you'd want to remember it." |

Optional 7th frame if you have room: privacy nutrition label hero
screen, or the Settings → Account → Delete pane with the calm copy
visible. Either reinforces the privacy story.

### Screenshot production notes

- Use the **`#if DEBUG` seed demo data** affordance
  (`App/Composition/DemoSeed.swift`) to plant the 10 curated
  memories. The screenshots Apple wants are best produced with rich,
  realistic data — not empty states.
- The included demo memories already use "Pamela", "Roatan", "the
  river loop" etc., which matches the homepage's example copy. Keep
  them aligned for brand consistency.
- Don't use the **welcome seed** memories (those say "Welcome to
  Orbit — this is your first memory") — they're meta and confuse
  the screenshot story.
- Avoid status-bar wifi/battery jitter: use the simulator's
  "Toggle Appearance" + "Device Bezels" or a tool like Picasso /
  Screenshot Designer if you want device frames.
- Run the screenshot session right after a fresh install + demo
  seed + the dynamic-type / dark-mode you want to ship with.

## Part 4 — App preview video (optional, max 30s)

Strongly recommended — App Store preview videos lift conversion ~20%
in Apple's own internal data. Keep it under 30 seconds. Suggested
arc:

- 0–3s: app icon → Timeline lands with the bloom animation
- 3–8s: tap the +, record a voice note, see the live transcript
- 8–14s: AI auto-tagging visible on the memory detail
- 14–20s: Daily Recap open, paragraph fade-in
- 20–26s: Ask Orbit answers a question, cards animate in
- 26–30s: end card — "Memories find their orbit." over the
  Orbit logo, no voiceover needed

Use the in-app theme animations as-is. No narration, no music more
prominent than a soft pad. Apple's own apps (Journal, Photos
Memories) do this exact treatment.

## Part 5 — Submission checklist

Run through this before you tap **Submit for Review** in App Store
Connect. Each item maps to something we shipped, audited, or wrote
on this branch.

- [ ] All `{{ placeholder }}` strings in `privacy.html` and
      `terms.html` resolved.
- [ ] Support page Q1 (iPad reference) and Q6 (iOS version) updated.
- [ ] Speech-fallback disclosure decision made and reflected on both
      privacy page Section 3 and support page Q4. Privacy
      nutrition-label declarations in App Store Connect match.
- [ ] "End-to-end iCloud" softened on `index.html`.
- [ ] Real support email working and updated across all four pages
      plus in-app `Settings → About → Contact Support`.
- [x] Real App Store app ID (`6769115384`) substituted across
      `index.html` (hero + end CTA) and `docs/marketing/landing.md`.
- [ ] App Store Connect: Privacy URL, Terms URL, Support URL all
      set and resolving.
- [ ] App Store Connect: privacy nutrition label declarations match
      `docs/PRIVACY_NUTRITION_LABEL.md`.
- [ ] App Store Connect: subscription product reviewed (price, trial
      length, display name, description ≤45 chars).
- [ ] Screenshot set produced on real device or accurate simulator
      with demo seed data.
- [ ] Cold-launch performance measured on real iPhone (you've got
      the signpost from the launch-perf pass for this).
- [ ] Account Deletion flow tested end-to-end (Apple 5.1.1(v)
      requirement).
- [ ] Real-device test of the three free-tier gate thresholds
      (Recap 3/wk, Ask 10/wk, voice 60s) and a successful 7-day
      yearly trial conversion in sandbox.

When every box is checked, the branch is genuinely ready to ship.
