# App Store Screenshots — copy, sequence, and composition

Revised against ButterKit's [App Store Screenshots Design Cheatsheet
(2026)](./Screenshots%20Cheatsheet.pdf). Ten screenshots, ordered as
a complete narrative: **problem → solution shape → AI magic → four
features → ecosystem → visual payoff → trust close.**

Apple shows up to **10** screenshots on the listing page. Research
shows ~89% of visitors never scroll past screenshot #3, so the first
three slots are tuned for instant comprehension; #4–10 reward
scrollers with depth.

Required size: **6.7" iPhone (1290 × 2796 px)** captured on an iPhone
16 Pro Max simulator. App Store derives the other device sizes
automatically.

---

## What the cheatsheet teaches (the rules we follow)

1. **Start with the problem, not the brand.** First slide identifies
   what the app fixes. +16.6% install lift vs. brand openers.
2. **89% never scroll past #3.** Slots 1–3 carry the conversion.
3. **Social proof early when possible.** Real quotes > marketing
   claims. (See "Honest social-proof gap" below for the v1
   workaround.)
4. **One focus per screenshot, ruthlessly concise.** Shorter is
   stronger.
5. **Max 3 typographic styles** (Title / Subtitle / optional Caption).
6. **Generous negative space.** Don't max out every element.
7. **Show actual app UI inside device frames** — except where the
   composition is intentionally text-driven (slides 1 and 10) or
   visual-payoff-driven (slide 9).

---

## The 10-screenshot sequence

Read the headlines top-to-bottom — they themselves are the pitch:

```
1. Memory shouldn't fail you.
2. One place. Everything saved.
3. It organizes itself.
4. A day, read back.
5. Ask your own memory.
6. Your past, on cue.
7. Tasks find themselves.
8. Wherever you are.
9. Worth sharing.
10. Nothing leaves your phone.
```

Visual rhythm across the deck (so the gallery doesn't feel monotonous):

| Slot | Background | Device frame? | Visual character |
|------|------------|---------------|------------------|
| 1 | dark `#0E0E0E` | no | editorial cover, big serif headline |
| 2 | off-white `#FBFAF7` | yes | product shot |
| 3 | off-white | yes | product shot (AI tags + summary visible) |
| 4 | off-white | yes | product shot (Daily Recap hero) |
| 5 | off-white | yes | product shot (Ask Orbit answer) |
| 6 | off-white | yes | product shot (year glyph hero) |
| 7 | off-white | yes | product shot (Tasks tab with suggestions) |
| 8 | **Aurora blue `#2D5BFF`** | **multi-device** | family composition (iPhone + Watch + DI + Widget) |
| 9 | off-white | no | bare share card at full bleed — visual peak |
| 10 | dark `#0E0E0E` | no | editorial back cover, checklist |

That's: editorial cover → 6 product shots → distinct ecosystem moment → visual peak → editorial back cover. A magazine in 10 pages.

---

## Composition template (default for product shots #2–#7)

```
┌──────────────────────────────────┐  1290 × 2796 canvas
│                                  │
│   HEADLINE                       │  108 pt SF Pro Display Bold
│   one line of subline.           │  36 pt SF Pro Display Medium
│                                  │
│   ┌──────────────────────────┐   │  iPhone 16 Pro Max
│   │                          │   │  black titanium frame
│   │     [app screen]         │   │  centered, slightly clipped
│   │                          │   │  at the bottom edge
│   │                          │   │
│   └──────────────────────────┘   │
│                                  │
└──────────────────────────────────┘
```

### Caption typography

- **Headline** — 108 pt, weight 700, SF Pro Display, tracking
  -0.025em, line height 1.05. Color = text-primary
  (`#111111` light / `#F4F1EB` dark).
- **Subline** — 36 pt, weight 500, SF Pro Display, tracking -0.005em,
  line height 1.3. Color = text-secondary (`#5C5C5C` / `#A8A8A8`).
- **Caption** (rare — only on the cover/back) — 24 pt, weight 500,
  small-caps tracked.

### Padding

- Top: 200 px before the caption headline
- Headline → subline: 24 px
- Subline → device frame: 120 px
- Side margins: 75 px

---

## Slide-by-slide

### 1 ▸ Problem opener

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Memory shouldn't fail you.`                  |
| Subline  | _(none — let the headline breathe)_           |

**Background:** dark `#0E0E0E`. **No device frame.**
**Composition:** Headline only, centered both axes in 88 pt serif
(New York), color `#F4F1EB`. Substantial negative space above and
below — the cheatsheet's "single chair on an empty stage" principle.
This is a magazine cover.

> **Why this slide:** Names the problem in one short sentence the
> reader has felt themselves. The cover image of the deck — sets the
> tone (calm, editorial, considered) and identifies who Orbit is for.

---

### 2 ▸ Solution shape

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `One place. Everything saved.`                |
| Subline  | `Text. Voice. Photos. Links. Places.`         |

**Background:** off-white `#FBFAF7`. **Device frame: yes.**
**App state:** Capture sheet open with the **mode switcher** visible
(Text / Voice / Photo / Link). Body field shows the bookshop seed-data
text. Keyboard dismissed.

> **Why this slide:** Answers "what is this app?" in one screen.
> Shows the breadth of capture types so the reader immediately
> understands the scope.

---

### 3 ▸ AI magic (the wow factor)

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `It organizes itself.`                        |
| Subline  | `Apple Intelligence does the filing.`         |

**Background:** off-white. **Device frame: yes.**
**App state:** Memory Detail view on the **bookshop voice note**
(seeded). Visible: voice waveform, transcript, AI-generated summary
card, 2–3 tag chips, the inferred category eyebrow at the top.

> **Why this slide:** The first 3 screenshots carry 90% of
> conversions. This is where the differentiation lands — "this app
> uses Apple Intelligence to do work for me." Slot #3 is the highest-
> stakes feature reveal in the deck.

---

### 4 ▸ Daily Recap

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `A day, read back.`                           |
| Subline  | `A reflection every evening — gentle, never demanded.` |

**Background:** off-white. **Device frame: yes.**
**App state:** Daily Recap sheet open for today. Day number (large
Aurora blue glyph), day-of-week in serif, narrative paragraph, stats
row, sleep + steps footer.

> **Why this slide:** Signature feature. No other journal/notes app
> generates editorial daily reflections from your captures. Visually
> distinctive — the big day glyph is a moment.

---

### 5 ▸ Ask Orbit

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Ask your own memory.`                        |
| Subline  | `Orbit answers from your captures. Never the cloud.` |

**Background:** off-white. **Device frame: yes.**
**App state:** Ask Orbit sheet with the Pamela question answered:
question at top, serif answer card with 2–3 sentence response,
sources section showing the linked memory chip.

> **Why this slide:** The biggest differentiator from every other
> memory app on the market — conversational query over your own
> data, on-device. "Holy shit, the AI knows about my own life"
> moment.

---

### 6 ▸ Past resurfacing

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Your past, on cue.`                          |
| Subline  | `On This Day · Year in Review · Time Capsules` |

**Background:** off-white. **Device frame: yes.**
**App state:** Year in Review sheet (use the time-travel workaround
in `seed-data.md` to force it). 220pt year glyph in Aurora blue,
serif headline, monthly sparkline, label/value rows.

> **Why this slide:** The emotional payoff — Orbit isn't just a
> capture tool, it brings your past back to you. Three named time
> features in the subline communicate the depth.

---

### 7 ▸ Tasks find themselves

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Tasks find themselves.`                      |
| Subline  | `Write "I should…" and Orbit listens.`        |

**Background:** off-white. **Device frame: yes.**
**App state:** Tasks tab open with:
- The **Suggestions** section populated (from the seeded memories
  that contained "I should…" patterns — the Dr. Tanaka follow-up,
  the Maria intro ask)
- A few **Open** tasks below

Show the chip that links each suggestion back to its source memory.

> **Why this slide:** Reveals Orbit's quiet intelligence — it
> auto-extracts to-dos from natural-language captures. Most apps
> require explicit task entry; Orbit makes them emerge. This is the
> kind of detail that converts "interested" into "wow."

---

### 8 ▸ The Apple ecosystem (multi-device composition)

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Wherever you are.`                           |
| Subline  | `Apple Watch · Widgets · Dynamic Island · Lock Screen` |

**Background:** Aurora blue `#2D5BFF` (solid). **No traditional
device frame — instead, a "device family" composition.**

This is the most production-complex slide. Three elements on one
canvas, all branded as Orbit:

```
┌──────────────────────────────────┐
│   WHEREVER YOU ARE.              │  ← headline in #F4F1EB
│   Apple Watch · Widgets · ...    │  ← subline
│                                  │
│   ┌────────────┐                 │
│   │ ▣  Capturing 0:08 ▢          │  ← iPhone Lock Screen
│   │                              │     showing Dynamic Island
│   │   [Orbit widget here]        │     with Live Activity
│   │                              │     pill at top, Orbit
│   │   The bookshop voice…        │     widget mid-screen
│   │                              │
│   │   [time]                     │
│   └────────────┘                 │
│                  ┌─────┐         │
│                  │ ▶ ◉ │         │  ← Apple Watch face
│                  │     │            showing voice capture
│                  │ 0:08│            (mic + timer)
│                  └─────┘
└──────────────────────────────────┘
```

**Composition details:**

1. **iPhone (center-left)** — Lock Screen rendering:
   - Dynamic Island pill at the top displaying the **Voice Capture
     Live Activity** ("Capturing… 0:08" with a tiny waveform glyph)
   - The **Orbit widget** in the Lock Screen widget area, showing a
     recent memory preview (use the bookshop note from the seed)
   - Time and date area visible above
   - Lock Screen wallpaper: solid black or a subtle pattern — keep
     it quiet so the Orbit elements pop
2. **Apple Watch (right side, slightly behind/below)** — showing the
   **voice capture screen** in Orbit's watch app: large red mic
   button, a small timer reading "0:08", waveform line beneath
3. **Caption labels** in small-caps tracked text under each device
   (optional): "Lock Screen + Dynamic Island" and "Apple Watch"

**Color treatment:** Both device renders against the solid Aurora
blue background. The iPhone Lock Screen is its own dark surface so
contrast is automatic. The Apple Watch face is dark too.

> **Why this slide:** No other slide can show that Orbit lives
> across the entire Apple ecosystem — most apps don't. This is the
> "premium native iOS app" credibility moment, and it visually
> stands out from the surrounding product shots because of the
> blue background and multiple devices.

> **Production note:** This is the only screenshot you can't capture
> cleanly with one `⌘S` from the simulator. Three sub-captures:
> (a) Lock Screen with widget + DI from the iPhone, (b) Apple Watch
> capture screen, then compose in ButterKit or Figma. ButterKit's
> device-frame library has both an iPhone Lock Screen template and
> an Apple Watch template — drop both onto a single 1290 × 2796
> canvas.

---

### 9 ▸ Share cards (the visual peak)

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Worth sharing.`                              |
| Subline  | `Editorial-quality images of any memory.`     |

**Background:** off-white `#FBFAF7`. **No device frame — bare share
card at near-full bleed.**

**Composition:** Take a rendered Orbit share card (from the actual
app — open Daily Recap or any memory, tap share, screenshot the
preview, save the PNG). The card is already a complete editorial
composition at 1080 × 1350 — 4:5 ratio.

Place the card centered on the canvas. Padding around it:
- ~120 px left/right margins so the card has room
- Headline + subline at top using the standard caption spec

The card's own typography becomes part of the screenshot's visual.
This is the most striking slide in the deck — Apple Music Replay
ads use this approach: just show the share artifact itself, big.

> **Why this slide:** Shows polish. Apps that produce beautiful
> output convert harder than apps that just *do* things. The share
> card communicates: "this thing makes me look good when I post."

---

### 10 ▸ Privacy close

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Nothing leaves your phone.`                  |
| Subline  | `On-device AI. No analytics. No ads.`         |

**Background:** dark `#0E0E0E`. **No device frame.**

**Composition:** Below the headline + subline, a 4-row vertical
checklist:

- ✓  On-device AI
- ✓  End-to-end iCloud
- ✓  No analytics or tracking
- ✓  No data sold or shared

Each row 56 pt SF Pro Display Medium in `#F4F1EB`, with a 36 pt
green `#3FAE6A` checkmark glyph as prefix. 28 pt vertical spacing
between rows. Centered horizontally on the canvas, anchored just
below the subline.

> **Why this slide:** Bookends the deck with the dark editorial
> treatment from slide 1 — gallery feels like a magazine cover →
> body → back cover. Privacy + on-device AI is one of Orbit's
> strongest sales points and the right trust signal to close on.

---

## Caption sequence at a glance (verification)

If a user reads only the headlines while scrubbing:

1. **Memory shouldn't fail you.**
2. **One place. Everything saved.**
3. **It organizes itself.**
4. **A day, read back.**
5. **Ask your own memory.**
6. **Your past, on cue.**
7. **Tasks find themselves.**
8. **Wherever you are.**
9. **Worth sharing.**
10. **Nothing leaves your phone.**

Reads as a coherent narrative on its own.

---

## Honest social-proof gap

The cheatsheet pushes social proof hard. The v1 launch doesn't have
real reviews yet, so this plan omits a quote-slot and instead leans
on **credibility signals** woven into the existing slides:

- "Apple Intelligence" namedrop on slide #3
- "Nothing leaves your phone" trust close on slide #10
- The ecosystem breadth on slide #8 (Watch / Widgets / Dynamic
  Island / Lock Screen) is itself a credibility signal — most apps
  don't ship across all those surfaces

**Once you have ~20 real reviews** (a few weeks after launch),
consider replacing slide #7 ("Tasks find themselves") with a
customer quote on the Aurora-blue background. Tasks moves into
slide #8 area if needed.

---

## Production paths

### Option A — ButterKit (recommended)

You have lifetime pro. See [`butterkit-prompts.md`](./butterkit-prompts.md)
for the ready-to-paste Claude Desktop prompts driving the MCP
integration — they include all 10 slides now.

### Option B — Figma (manual)

1. Frame 1290 × 2796 per slide.
2. iPhone 16 Pro Max mockup from [Apple Design Resources](https://developer.apple.com/design/resources/).
3. Paste simulator screenshot into device frame.
4. Add caption layers per the typography spec.
5. Export each as PNG.

The ecosystem slide (#8) requires more work in either tool — you'll
need to composite an iPhone Lock Screen mockup and an Apple Watch
mockup onto a single canvas. Both tools have these templates.

---

## App Preview video (optional, post-launch)

App Preview videos boost conversion ~25% on top of strong
screenshots. Cut sheet for a 30s preview:

- 0–3s: Capture sheet → type → save
- 4–7s: Timeline updates, AI summary fades in
- 8–14s: Daily Recap renders, scroll through it
- 15–22s: Ask Orbit, type question, watch answer
- 23–28s: Share a memory as a card
- 29–30s: Orbit logo title card

Record on a real device via Xcode → Device → Window → Screen
Recording. Export 1080 × 1920 H.264 .mov, ≤500 MB.
