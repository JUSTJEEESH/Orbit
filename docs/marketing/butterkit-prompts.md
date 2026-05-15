# ButterKit prompts (for Claude Desktop)

Paste these into a **Claude Desktop** chat with the ButterKit MCP
connected. Paste them in order. Each builds on the previous step.

**Important:** these only work in Claude Desktop (the local Mac app),
not in web/cloud Claude. The MCP server runs locally and is only
reachable from the local client. To confirm you're in the right app:
the window has no browser address bar.

---

## Prompt 1 — Verify connection

```
List all my open ButterKit documents and the tools you have available.
I want to confirm the MCP integration is working before we start
building.
```

Expected: ~40 ButterKit tools listed (`document_list`,
`document_create`, `screen_create`, `asc_create_version`, etc.) and
either zero open documents or whatever projects you have open.

---

## Prompt 2 — Set up the project

```
I'm building App Store screenshots for an iOS app called Orbit — a
calm AI second-brain for capturing memories. We need 10 portrait
screenshots at 1290 × 2796 (iPhone 6.7"). The visual system mirrors
the in-app design system:

Background palette:
- Off-white #FBFAF7 for slides 2, 3, 4, 5, 6, 7, 9
- Dark #0E0E0E for slides 1 and 10
- Aurora blue #2D5BFF for slide 8

Typography:
- Headlines: SF Pro Display Bold (or New York Serif for slide 1)
- Sublines: SF Pro Display Medium
- Optional Caption: small-caps tracked

Device frame: iPhone 16 Pro Max black titanium on slides 2–7.
No device frame on slides 1, 8, 9, 10 (those are composed compositions).

Accent color: Aurora #2D5BFF (light), #5A82FF (dark).

Create a new ButterKit project with 10 empty artboards at the right
size. Confirm when ready.
```

---

## Prompt 3 — Apply the captions (the big one)

Paste this whole block in one message:

```
Set up the 10 screenshots with these captions and treatments, in this
exact order. Narrative arc: problem → solution shape → AI magic →
features → ecosystem → visual payoff → trust close.

Slide 1 — Problem opener
  Background: dark #0E0E0E
  No device frame
  Centered both axes
  Headline (serif New York, 88pt, weight semibold, color #F4F1EB):
    "Memory shouldn't fail you."
  No subline. Generous negative space above and below.

Slide 2 — Solution shape
  Background: light #FBFAF7
  Device frame: iPhone 16 Pro Max black titanium, centered, slightly
    bottom-clipped
  Headline top-aligned (SF Pro Display Bold 108pt, #111111):
    "One place. Everything saved."
  Subline (SF Pro Display Medium 36pt, #5C5C5C):
    "Text. Voice. Photos. Links. Places."

Slide 3 — AI magic
  Background: light #FBFAF7
  Device frame: same as slide 2
  Headline: "It organizes itself."
  Subline: "Apple Intelligence does the filing."

Slide 4 — Daily Recap
  Background: light #FBFAF7
  Device frame: same
  Headline: "A day, read back."
  Subline: "A reflection every evening — gentle, never demanded."

Slide 5 — Ask Orbit
  Background: light #FBFAF7
  Device frame: same
  Headline: "Ask your own memory."
  Subline: "Orbit answers from your captures. Never the cloud."

Slide 6 — Past resurfacing
  Background: light #FBFAF7
  Device frame: same
  Headline: "Your past, on cue."
  Subline: "On This Day · Year in Review · Time Capsules"

Slide 7 — Found tasks
  Background: light #FBFAF7
  Device frame: same
  Headline: "Tasks find themselves."
  Subline: "Write 'I should…' and Orbit listens."

Slide 8 — Apple ecosystem (multi-device composition)
  Background: solid Aurora #2D5BFF
  No traditional device frame — instead a multi-device composition
  Headline top-aligned (SF Pro Display Bold 96pt, #F4F1EB):
    "Wherever you are."
  Subline (SF Pro Display Medium 32pt, #F4F1EB at 75% opacity):
    "Apple Watch · Widgets · Dynamic Island · Lock Screen"
  Body composition (see Prompt 5 below for the detailed build):
    - iPhone Lock Screen rendering with Dynamic Island Live Activity
      pill + Orbit widget mid-screen
    - Apple Watch face beside/below the iPhone showing voice capture
      (large mic button, timer "0:08", waveform line)

Slide 9 — Share card (visual peak)
  Background: light #FBFAF7
  No device frame — the Orbit share-card image itself is the hero
  Headline top-aligned (SF Pro Display Bold 108pt, #111111):
    "Worth sharing."
  Subline (36pt, #5C5C5C):
    "Editorial-quality images of any memory."
  Below the caption block, an actual rendered Orbit share card
  (1080 × 1350) placed centered with ~120px side margins.

Slide 10 — Privacy close
  Background: dark #0E0E0E
  No device frame
  Headline (SF Pro Display Bold 72pt, #F4F1EB, top-aligned):
    "Nothing leaves your phone."
  Subline (36pt, #A8A8A8):
    "On-device AI. No analytics. No ads."
  Below the subline, a 4-row vertical checklist centered horizontally
  (each row 56pt SF Pro Display Medium #F4F1EB, with a 36pt green
  #3FAE6A checkmark prefix, 28pt vertical spacing between rows):
    ✓  On-device AI
    ✓  End-to-end iCloud
    ✓  No analytics or tracking
    ✓  No data sold or shared

Common padding: 200px top before headlines, 24px between headline
and subline, 120px between subline and device frame / hero element,
75px side margins. Top-align everything except slide 1 which is
centered both axes.

Apply all of this, then show me the artboards.
```

---

## Prompt 4 — Drop in the simulator screenshots

```
Place these PNGs from my Mac into the matching device frames on
slides 2 through 7. Adjust path if your folder is somewhere else:

- ~/Desktop/orbit-app-store/02-capture.png         → slide 2 (Capture sheet)
- ~/Desktop/orbit-app-store/03-ai-filing.png       → slide 3 (Memory Detail w/ AI)
- ~/Desktop/orbit-app-store/04-daily-recap.png     → slide 4 (Daily Recap)
- ~/Desktop/orbit-app-store/05-ask-orbit.png       → slide 5 (Ask Orbit)
- ~/Desktop/orbit-app-store/06-year-in-review.png  → slide 6 (Year in Review)
- ~/Desktop/orbit-app-store/07-tasks.png           → slide 7 (Tasks tab)

Slides 1, 8, 9, and 10 are composed in ButterKit (no simulator
capture needed for those).
```

You'll need to capture a new simulator screenshot for slide 7 (Tasks
tab with suggestions populated) — see `seed-data.md` for how to
populate the tasks suggestions naturally from the seeded memories.

---

## Prompt 5 — Build the ecosystem composition (slide 8)

This is the most complex slide. ButterKit's device library should
have both an iPhone Lock Screen template and an Apple Watch
template — we composite both onto the Aurora canvas.

```
Slide 8 needs a multi-device composition. Walk me through it step by
step:

Step A: Set the canvas background to solid Aurora #2D5BFF.

Step B: Place an iPhone 16 Pro Max Lock Screen template centered
slightly left of center, scaled to ~80% of canvas height. The Lock
Screen content should show:
  - A Dynamic Island pill at the top with a Live Activity label
    reading "Capturing  0:08" and a tiny waveform icon
  - An Orbit widget in the Lock Screen widget area (just below the
    time). The widget should show "Latest memory" + a short preview
    line of body text
  - Default time display

Step C: Place an Apple Watch (Series 10 or latest) template to the
right of the iPhone, sized at ~30% of the iPhone's height, positioned
so it overlaps the iPhone's bottom-right edge slightly. The watch
face should show:
  - A large circular red record button in the center
  - A timer reading "0:08" below the button
  - A small waveform line at the very bottom

Step D: Optionally add tiny small-caps labels under each device:
  - Under iPhone: "LOCK SCREEN · DYNAMIC ISLAND · WIDGETS"
  - Under Watch: "APPLE WATCH"
  Both in #F4F1EB at 50% opacity, 18pt tracked.

Step E: The headline "Wherever you are." remains top-aligned at the
original 200px from top.

Show me the result before exporting.
```

---

## Prompt 6 — Build the share card hero (slide 9)

```
Slide 9 needs the bare share card as the hero. Two ways to do this:

Option A: Use a rendered share card image from my Mac.
  Path: ~/Desktop/orbit-app-store/share-card-sample.png
  (Capture this from the running app: open Daily Recap, tap share,
  save the preview PNG, place it at the path above.)

Option B: Compose a placeholder if the image isn't ready yet.
  Use ButterKit's text-only layout with:
    - A solid #FBFAF7 background card sized 1080 × 1350
    - An Orbit logo mark at the top in Aurora #2D5BFF, ~80px
    - A serif (New York) hero quote in the middle in dark #111111
    - A small "Daily Recap · May 13" footer label

Use Option A if the file exists; fall back to Option B otherwise.
Center the card in the slide with 120px side margins. Headline
"Worth sharing." stays top-aligned.
```

---

## Prompt 7 — Compose the no-device-frame text slides (1, 10)

Slides 1 and 10 are pure typography compositions. Prompt 3 should
have set them up correctly, but verify:

```
Slides 1 and 10 should be pure text compositions — no device
frames, no app UI.

Slide 1: Dark #0E0E0E background, single serif headline centered
both vertically and horizontally, substantial breathing room. Just
that one element of text.

Slide 10: Dark #0E0E0E background, top-aligned bold sans headline
and subline, then the 4-line check-marked list centered horizontally
just below the subline.

Verify both. Fix anything that doesn't match.
```

---

## Prompt 8 — Export

```
Export all 10 artboards as PNG at 1290 × 2796 to
~/Desktop/orbit-app-store-final/. Filename them so App Store Connect
orders them correctly in the upload UI:

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

---

## Prompt 9 — Upload to App Store Connect

You need to be signed in to App Store Connect inside ButterKit first
(Settings → App Store Connect → Sign in).

```
Upload the 10 English screenshots from ~/Desktop/orbit-app-store-final/
to App Store Connect for the "Orbit" app, version 1.0, iPhone 6.7"
display size.
```

---

## Localization (later, post-launch)

Once English is shipping cleanly:

```
Add French, German, Spanish, Japanese, and Portuguese (BR)
localizations to this project. Translate every headline and subline,
keeping caption character counts close to the English version.
Use App Store Connect language codes: fr, de, es-ES, ja, pt-BR.

When done, export the translated artboards into language-suffixed
folders (e.g. ~/Desktop/orbit-app-store-final/fr/, etc.) and upload
each set to the matching App Store Connect localization.
```

---

## Common gotchas

| Symptom | Fix |
|---|---|
| "I don't see any ButterKit tools" | You're talking to cloud/web Claude, not Claude Desktop. Switch apps. |
| Tools listed but `document_list` errors | ButterKit isn't running. With `--auto-launch` configured it should boot on connect — if not, open ButterKit manually first. |
| Captions look misaligned | The padding numbers (200 / 24 / 120 / 75) are the spec. Tell Claude Desktop to re-apply them. |
| Device frame is wrong model | "Switch all device frames to iPhone 16 Pro Max black titanium." |
| Slide 8 looks crowded | The Watch should be ~30% of the iPhone's height, not equal-sized. Both devices need negative space around them. |
| Export wrote wrong dimensions | Confirm artboard size is 1290 × 2796, not 1320 × 2868 (the iPhone 16 Pro Max canvas size). 1290 × 2796 is what App Store actually requires. |
| Live Activity pill on slide 8 looks fake | Use ButterKit's Dynamic Island Live Activity template if available; otherwise use a black pill shape with white text content. Aim for visual recognizability over pixel-perfect accuracy. |
