# App Store Screenshots — copy, sequence, and composition

Revised against ButterKit's [App Store Screenshots Design Cheatsheet
(2026)](./Screenshots%20Cheatsheet.pdf), which distills SplitMetrics +
peer-reviewed research into a 14-point conversion playbook. The
sequence below puts the **problem first**, social proof early, and
features as the solution — the structure that converts highest.

Apple shows up to **10** screenshots on the listing page. Research
shows ~89% of visitors never scroll past screenshot #3, so the first
three slots carry almost all the conversion weight.

Required size: **6.7" iPhone (1290 × 2796 px)** captured on an iPhone
16 Pro Max simulator. App Store derives the other device sizes
automatically.

---

## What the cheatsheet teaches

Eight rules we're aligning to:

1. **Start with the problem, not the brand.** First 1–2 screenshots
   should answer "what problem does this app solve for me?" Apps
   that lead with the most explanatory screenshot see a **+16.6%
   install lift** vs. brand openers.
2. **89% of users never scroll past screenshot #3.** Almost all
   conversion weight lives in the first three.
3. **Social proof early.** Customer quotes, awards, or download
   counts in slots #1–3 — real users' words convert harder than your
   marketing claims.
4. **One focus per screenshot, ruthlessly concise.** Shorter
   captions beat longer ones.
5. **Maximum 3 typographic styles** total (Title / Subtitle /
   optional Caption).
6. **Use real design.** Avoid AI-generated slop. Hand-crafted reads
   trustworthy.
7. **Generous negative space.** Don't max out every element.
8. **Show actual app UI inside device frames.** Brand-mark openers
   without a phone undersell.

The 14-point checklist (from the cheatsheet, all in scope):

- [x] Start with the problem your app solves in the first 1–2 screenshots
- [x] Present features as solutions to that problem
- [x] Structure screenshots as a storyboard with a clear narrative
- [ ] Include social proof early (reviews / downloads / awards / press)  ← see "Honest social-proof gap" below
- [x] Limit color palette (Aurora blue + neutrals)
- [x] No more than 3 typographic styles (headline / subline / caption)
- [x] Generous negative space
- [x] One focus point per screenshot, ruthlessly concise
- [x] Consistent colors / typography / layout / storytelling
- [x] Real design — no AI slop
- [x] Use a professional template (ButterKit)
- [x] Put your 3 most compelling first
- [x] Show actual app UI inside device frames
- [ ] Translate and localize for each target market  ← v1 ships English-only; localize in v1.1

---

## Composition template (apply to every screenshot)

```
┌──────────────────────────────────┐  ← 1290 × 2796 canvas
│                                  │     solid background (see below)
│   CAPTION HEADLINE               │  ← 2–4 words, 108pt bold,
│   one line of supporting copy.   │     SF Pro Display, top-aligned
│                                  │
│   ┌──────────────────────────┐   │  ← device frame, centered
│   │                          │   │     (iPhone 16 Pro Max bezel),
│   │     [app screen]         │   │     ~1140px wide
│   │                          │   │
│   │                          │   │
│   │                          │   │
│   └──────────────────────────┘   │
│                                  │
└──────────────────────────────────┘
```

### Caption typography

Three styles max — that's the cheatsheet's rule.

- **Headline** — 108 pt, weight 700, SF Pro Display, tracking -0.025em,
  line height 1.05. Color = text-primary (`#111111` on light bg,
  `#F4F1EB` on dark bg).
- **Subline** — 36 pt, weight 500, SF Pro Display, tracking -0.005em,
  line height 1.3. Color = text-secondary (`#5C5C5C` light /
  `#A8A8A8` dark).
- **Caption** (optional, only screenshot #3) — 24 pt, weight 500,
  small-caps tracked, for the review attribution.

### Background

- Default: **`#FBFAF7`** (off-white) for screenshots #2, #4–#7.
- **`#0E0E0E`** (dark) for the problem opener (#1) and the privacy
  close (#8) — bookends the gallery.
- **`#2D5BFF`** (Aurora accent) for the social-proof quote (#3) —
  so the quote pops visually inside the sequence.

### Device frame

iPhone 16 Pro Max, black titanium. No drop shadow, no bezel
reflection. Slightly clipped at the bottom of the canvas.

### Padding

- Top: 200 px before the caption headline
- Headline → subline: 24 px
- Subline → device frame: 120 px
- Side margins: 75 px

---

## The sequence (8 screenshots)

Read the headlines top-to-bottom — they should themselves be the
elevator pitch. They do here: problem → solution → trust → AI →
recap → ask → past → privacy.

### 1 ▸ The problem (was: brand opener)

**Background:** dark `#0E0E0E`. No device frame. Text composition.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Eyebrow  | _(none — strip the eyebrow on this one)_      |
| Headline | `The moments worth keeping keep slipping away.` |
| Subline  | _(none)_                                      |

**What's on screen:** Just the headline, centered, large (serif —
New York), with substantial vertical breathing room above and below.
This is a magazine cover, not a product screenshot.

> Cheatsheet alignment: rule #1 (start with the problem). This was
> previously a brand-mark opener, which the data calls out as a
> conversion mistake for indie launches.

---

### 2 ▸ The solution intro

**Background:** light `#FBFAF7`. Device frame.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `One app. Everything you remember.`           |
| Subline  | `Text · voice · photos · links · places.`     |

**App state:** Capture sheet open with the **mode switcher**
visible (Text / Voice / Photo / Link). Body field shows the bookshop
text from the seed data (so it reads as a real thought, not Lorem
ipsum). Keyboard dismissed.

---

### 3 ▸ Social proof / credibility

**Background:** solid Aurora `#2D5BFF`. No device frame. Centered
typography composition.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `"Finally, a second brain that actually feels calm."` |
| Caption  | `— Early review` (small-caps below)           |

**What's on screen:** Just the quote, in big serif (New York) at
96pt, centered, color `#F4F1EB`. Below it the attribution in 24pt
tracked small-caps. Lots of negative space.

> Cheatsheet alignment: rule #4 (social proof early). See "Honest
> social-proof gap" below — we're using an early-tester quote
> placeholder until real reviews land in v1.1.

---

### 4 ▸ AI hiding itself

**Background:** light `#FBFAF7`. Device frame.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `AI does the filing.`                         |
| Subline  | `Titles. Tags. Summaries. All on-device.`     |

**App state:** Memory Detail view on the **bookshop voice note**
(seeded memory #1). Show the auto-inferred category eyebrow, the
voice waveform + transcript, and the AI-generated summary + tag
chips lower down.

---

### 5 ▸ Daily Recap

**Background:** light `#FBFAF7`. Device frame.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `One paragraph, every evening.`               |
| Subline  | `A reflection of your day, gentle.`           |

**App state:** Daily Recap sheet open for today. 168pt day number in
Aurora blue, day-of-week in serif, narrative paragraph, stats row,
sleep + steps footer.

---

### 6 ▸ Ask Orbit

**Background:** light `#FBFAF7`. Device frame.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Chat with your memories.`                    |
| Subline  | `Orbit answers from your captures.`           |

**App state:** Ask Orbit sheet with the Pamela question answered:
question at top, serif answer card with sources beneath.

---

### 7 ▸ Time / resurfacing

**Background:** light `#FBFAF7`. Device frame.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Your past, on cue.`                          |
| Subline  | `On This Day · Year in Review · Time Capsules` |

**App state:** Year in Review sheet (time-travel the simulator clock
to Dec 28 — see [`seed-data.md`](./seed-data.md) for the workaround).
220pt year glyph in Aurora, sparkline, label/value rows.

---

### 8 ▸ Privacy close

**Background:** dark `#0E0E0E`. No device frame. Centered checklist.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Nothing leaves your phone.`                  |
| Subline  | `On-device AI. No analytics. No ads.`         |

**What's on screen:** Four-row checklist, each row 56pt SF Pro
Display Medium in `#F4F1EB` with a 36pt green `#3FAE6A` checkmark:

- ✓  On-device AI
- ✓  End-to-end iCloud
- ✓  No analytics or tracking
- ✓  No data sold or shared

---

## Caption sequence at a glance (verification)

If a user scrubs the gallery and reads only the headlines:

1. **The moments worth keeping keep slipping away.**
2. **One app. Everything you remember.**
3. **"Finally, a second brain that actually feels calm."**
4. **AI does the filing.**
5. **One paragraph, every evening.**
6. **Chat with your memories.**
7. **Your past, on cue.**
8. **Nothing leaves your phone.**

That's the pitch.

---

## Honest social-proof gap

The cheatsheet pushes hard on social proof, but a v1 launch has no
real reviews yet. Three options:

**A. Run TestFlight beta for 2 weeks, collect real quotes.** Send
Orbit to 5–15 testers, ask each for one sentence, pick the most
honest line for screenshot #3. **Most legitimate path.** Adds ~2
weeks to launch timeline.

**B. Replace #3 with a credibility signal that isn't a quote.**
Examples:
- "Built on Apple Intelligence" + Apple logo
- The privacy checklist as the credibility signal
- A specific concrete stat ("100% on-device AI" / "Zero analytics
  SDKs")

**C. Skip social proof at v1, swap in another feature.** Acceptable;
you'll still beat 80% of indie listings on the rest of the
cheatsheet.

**Recommendation: B for launch, A by v1.1.** Lead with the "Built
on Apple Intelligence" credibility signal (or just the bare quote
placeholder above with `— Early review` if you've had any beta
tester feedback at all), and swap it for a real customer review
within a month of shipping when real reviews land.

---

## Production paths

### Option A — ButterKit (recommended)

ButterKit is the dedicated screenshot composition tool you have a
lifetime pro license for. Templates, device frames, multi-language
export, and direct App Store Connect upload are all built in. Drive
it from **Claude Desktop** with the MCP server you configured — see
[`butterkit-prompts.md`](./butterkit-prompts.md) for the
ready-to-paste prompts.

### Option B — Figma (manual fallback)

1. Frame 1290 × 2796 per screenshot.
2. Import iPhone 16 Pro Max mockup from [Apple Design Resources](https://developer.apple.com/design/resources/).
3. Paste your simulator screenshot inside the device frame.
4. Add caption layers using the typography spec above.
5. Export each frame as PNG.

### Option C — Fastlane snapshot (for ongoing releases)

`fastlane snapshot` + `frameit` can regenerate on every release.
Heavier setup; worth it once you ship updates monthly or want
localization at scale.

---

## App Preview video (optional, post-launch)

App Preview videos boost conversion ~25% on top of strong
screenshots, but are not required for v1. Cut sheet:

- 0–3s: Capture sheet → type → save
- 4–7s: Timeline updates, AI summary fades in
- 8–14s: Daily Recap, scroll through content
- 15–22s: Ask Orbit, type question, watch answer render
- 23–28s: Share a memory as a card
- 29–30s: Orbit logo title card

Record on a real device via Xcode → Device → Window → Screen
Recording. Export 1080 × 1920 H.264 .mov, ≤500 MB.
