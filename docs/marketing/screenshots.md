# App Store Screenshots — copy, sequence, and composition

Apple shows up to **10** screenshots on the listing page. Most users
swipe through the first 2–3 before deciding, so the sequence below
is ordered by impact, not by app navigation.

Required size: **6.7" iPhone (1290 × 2796 px)** captured on an
iPhone 15 Pro Max / 16 Pro Max simulator. App Store derives the other
device sizes automatically.

---

## Composition template (apply to every screenshot)

All eight screenshots share the same chrome so the listing reads as a
unified gallery — the way Apple Journal, Things 3, and Day One do it.

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

- **Headline**: 108 pt, weight 700, SF Pro Display, tracking -0.025em,
  line height 1.05. Color = brand text-primary (off-black light,
  off-white dark).
- **Subline**: 36 pt, weight 500, SF Pro Display, tracking -0.005em,
  line height 1.3. Color = text-secondary.
- **Eyebrow** (optional, for the brand opener): 22 pt, weight 600,
  tracking 0.16em, all caps, in the **accent blue** (`#2D5BFF`).

### Background

- Default: **`#FBFAF7`** (the app's off-white) for a calm gallery feel.
- Screenshots #1 (brand opener) and #8 (privacy close) use a
  **dark variant `#0E0E0E`** so the sequence has a satisfying frame
  and ends as confidently as it begins.

### Device frame

Use a clean iPhone 16 Pro Max frame, **black titanium**. No drop
shadow. No screen bezel reflection. The frame should be slightly
clipped at the bottom of the canvas — gives a sense of the phone
extending beyond, very Apple Journal.

### Padding

- Top: 200 px before the caption headline
- Between headline and subline: 24 px
- Between subline and device frame: 120 px
- Side margins: 75 px

---

## The sequence (8 screenshots)

### 1 ▸ Brand opener

**Dark background.** Sets the tone. No device frame on this one —
just the Orbit wordmark + glyph, oversized, with the tagline beneath.
Think Apple Journal's first screenshot: a brand statement.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Eyebrow  | `AI · SECOND BRAIN`                           |
| Headline | `Memories find their orbit.`                  |
| Subline  | `A calm second brain for iPhone.`             |

**What's on screen:** centered Orbit logo glyph (the atom) at ~280px,
followed by the wordmark "Orbit" at ~96pt below it. Below that, in
serif, the tagline at 56pt. Background `#0E0E0E`.

---

### 2 ▸ The capture moment

The single most important screen. Shows that capture is one tap.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Capture anything, in seconds.`               |
| Subline  | `Text, voice, photos, links, a place — all in one timeline.` |

**App state to capture:**
- Open the **Capture** sheet
- Type a real-feeling memory in the text field, e.g.
  *"Need to remember the name of that bookshop in Roatan — the owner gave me a coffee."*
- Show the **mode switcher** at the top (Text · Voice · Photo · Link)
  with **Text** selected
- The Save button visible at the bottom

---

### 3 ▸ AI hiding itself

Shows the magic without screaming about it. A memory detail view
where AI has already added a summary, tags, and category.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Apple Intelligence does the filing.`         |
| Subline  | `Titles. Tags. Summaries. All on-device while you write.` |

**App state to capture:**
- Open a **Memory Detail** view on a captured voice note
- Show the AI-generated summary at the top
- Show the inferred category eyebrow (e.g. **Travel · 4:32 PM**)
- Show 2–3 generated tags as chips beneath the body
- The audio waveform + transcript should be visible

---

### 4 ▸ Daily Recap (signature feature)

The most distinctively "Orbit" surface — leads with editorial
typography. This is also the share card in disguise, which sells
the visual quality of the app.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `One paragraph, every evening.`               |
| Subline  | `A reflection of your day — gentle, never demanded.` |

**App state to capture:**
- Open the **Daily Recap** sheet for today
- Make sure the day has 4–6 captures so the narrative has content
- Show the big day number, weekday in serif, narrative paragraph,
  and the captures stat
- Bonus: scroll so the first highlight memory card is just visible

---

### 5 ▸ Ask Orbit (the differentiator)

This is the demo. Question + answer + sources. Most powerful "wow
factor" screen in the listing.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Chat with your own memories.`                |
| Subline  | `Orbit answers from your captures. Never the cloud.` |

**App state to capture:**
- Open the **Ask Orbit** sheet
- Show a real-feeling answered question, e.g.
  - Question (in the field/header): *"What did Pamela say about the restaurant?"*
  - Answer card showing a 2–3 sentence Orbit response
  - **Sources** section below showing 2–3 source memory chips
- Use serif for the answer body (Orbit already styles it that way)

---

### 6 ▸ Share-worthy moments

Sells the share-card feature, which doubles as a product polish
signal. Show the actual rendered share card.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Worth remembering. Worth sharing.`           |
| Subline  | `Turn any memory or recap into a beautifully framed image.` |

**App state to capture:**
- Open a memory's share sheet *or*
- A standalone preview of the **Daily Recap share card**
  rendered at 1080 × 1350 with the brand mark + day number hero
- If using the system share sheet preview, make sure the card image
  is the dominant element

---

### 7 ▸ On This Day / Year in Review

Sells the **time** dimension — the app's emotional payoff. Choose
Year in Review for the dramatic year glyph.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Headline | `Your past, surfaced at the right moment.`    |
| Subline  | `On This Day · Year in Review · Time Capsules` |

**App state to capture:**
- Open the **Year in Review** sheet
- Show the year hero (the 220pt year number in accent blue)
- Show the headline ("[N] memories — a year in motion.")
- Show the monthly sparkline below
- Show at least one highlight row visible at the bottom

---

### 8 ▸ Private by design (closing trust signal)

**Dark background.** Closes the sequence the way it opened, with a
brand statement — but the brand statement here is the privacy
promise.

| Field    | Copy                                          |
|----------|-----------------------------------------------|
| Eyebrow  | `PRIVACY · ON DEVICE`                         |
| Headline | `Nothing leaves your phone.`                  |
| Subline  | `On-device AI. End-to-end iCloud. No analytics. No ads.` |

**What's on screen:** no device frame. Instead, a centered visual
composition matching screenshot #1:
- A small Orbit glyph in the accent color
- Four short label lines stacked vertically, each prefixed with a
  small green checkmark:
  - `On-device AI`
  - `End-to-end iCloud`
  - `No analytics or tracking`
  - `No data sold or shared`

Background `#0E0E0E`. Same dark variant as screenshot #1 — bookends
the sequence.

---

## Caption sequence at a glance (for verification)

This is what your gallery reads like if a user only sees the
headlines while scrubbing through:

1. **Memories find their orbit.**
2. **Capture anything, in seconds.**
3. **Apple Intelligence does the filing.**
4. **One paragraph, every evening.**
5. **Chat with your own memories.**
6. **Worth remembering. Worth sharing.**
7. **Your past, surfaced at the right moment.**
8. **Nothing leaves your phone.**

Read top-to-bottom. That's the elevator pitch. If the sequence
doesn't read as a story on its own, the screenshots aren't doing
their job — but this one does.

---

## How to actually produce these

### Option A — Hand-composed in Figma (recommended)

1. Set up a 1290 × 2796 frame for each screenshot.
2. Import the iPhone 16 Pro Max mockup ([free from Apple's
   Design Resources](https://developer.apple.com/design/resources/)).
3. Take a clean simulator screenshot at iPhone 16 Pro Max resolution
   in the app, then paste it inside the device frame.
4. Add the caption stack at top using the typography spec above.
5. Export as PNG at 1290 × 2796.

### Option B — Automated with Fastlane snapshot

If you want to regenerate screenshots on every release:

1. Install [`fastlane snapshot`](https://docs.fastlane.tools/getting-started/ios/screenshots/).
2. Write a UI test per screenshot that drives the app into the
   right state (open Daily Recap, fill in a memory, etc).
3. Use [`frameit`](https://docs.fastlane.tools/actions/frameit/) to
   wrap them in device frames with captions auto-pulled from a
   `title.strings` file.

For a v1 launch with eight screenshots, Option A is faster (a few
hours total) and gives you more visual control. Switch to Option B
once you ship updates regularly.

### Localization

If you ever ship localized listings, the caption headlines are short
enough (2–6 words each) that translation is a 30-minute pass per
language. The subline is where most of the localization effort goes.

---

## App Preview video (optional)

App Preview videos play autoplay in the listing and convert ~25%
better than screenshots alone when done well. If you want one:

- **15–30 seconds** of real app usage, no animations or text overlays
  (Apple's guidelines forbid lifestyle footage or non-app content).
- Suggested cut:
  1. **0–3s** — open the Capture sheet, type a one-line memory, hit save.
  2. **4–7s** — timeline updates, AI summary fades in on the new card.
  3. **8–14s** — tap Daily Recap pill, scroll through the recap content.
  4. **15–22s** — open Ask Orbit, type a question, watch the answer render.
  5. **23–28s** — share a memory as a card, system share sheet appears.
  6. **29–30s** — Orbit logo + tagline title card.
- Record the screen via Xcode → **Device → Window → Screen Recording**
  on a real device for the best fidelity.
- Trim and export as **1080 × 1920** H.264 .mov, ≤500 MB.

Apple lets you submit one App Preview per device size. You can ship
without one for v1 and add later.
