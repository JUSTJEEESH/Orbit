# ButterKit prompts (for Claude Desktop)

These are the prompts to paste into a Claude Desktop chat once your
ButterKit MCP server is connected. Paste them in order. Each one
builds on the previous step.

**Important: paste these into Claude Desktop, not into web/cloud
Claude.** The MCP server only exists in Claude Desktop's process,
so cloud Claude can't drive ButterKit. To confirm you're in the
right app: the window has no browser address bar, the menu bar
says "Claude" when the window is active.

---

## Prompt 1 — Verify connection and orient

```
List all my open ButterKit documents and the tools you have available.
I want to confirm the MCP integration is working before we start
building.
```

Expected response: a list of ~40 ButterKit tools (`document_list`,
`document_create`, `screen_create`, `asc_create_version`, etc.) plus
either zero open documents (clean state) or the names of any
projects you have open.

---

## Prompt 2 — Set up the project

```
I'm building App Store screenshots for an iOS app called Orbit — a
calm AI second-brain for capturing memories. We'll need 8 portrait
screenshots at 1290 × 2796 (iPhone 6.7"). The visual system mirrors
the in-app design:

- Off-white background (#FBFAF7) for screenshots 2, 4, 5, 6, 7
- Dark background (#0E0E0E) for screenshots 1 and 8
- Aurora-blue background (#2D5BFF) for screenshot 3
- Accent color across all: Aurora #2D5BFF light / #5A82FF dark
- Typography: SF Pro Display Bold for headlines, SF Pro Display
  Medium for sublines, optional small-caps for review attribution
- iPhone 16 Pro Max black-titanium device frame on screenshots 2, 4,
  5, 6, 7. No device frame on 1, 3, 8.

Create a new ButterKit project with these parameters and 8 empty
artboards at the right size. Confirm when ready.
```

---

## Prompt 3 — Apply the captions (the big one)

Paste this entire block in a single message:

```
Set up the 8 screenshots with these captions and treatments, in this
exact order. The narrative arc is problem → solution → social proof →
features → privacy close. Every headline is 4 words or fewer.

Screenshot 1 — Problem opener
  Background: dark #0E0E0E
  No device frame
  Headline (centered, serif New York 88pt, #F4F1EB):
    "The moments worth keeping keep slipping away."

Screenshot 2 — Solution intro
  Background: light #FBFAF7
  Device frame: iPhone 16 Pro Max black titanium, centered, bottom-clipped
  Headline (top-aligned, SF Pro Display Bold 108pt, #111111):
    "One app. Everything you remember."
  Subline (SF Pro Display Medium 36pt, #5C5C5C):
    "Text · voice · photos · links · places."

Screenshot 3 — Social proof
  Background: solid Aurora #2D5BFF
  No device frame
  Headline (centered, serif New York 96pt, #F4F1EB):
    '"Finally, a second brain that actually feels calm."'
  Attribution (small-caps tracked 24pt, semibold, #F4F1EB at 70% opacity):
    "— EARLY REVIEW"

Screenshot 4 — AI metadata
  Background: light #FBFAF7
  Device frame: same as #2
  Headline: "AI does the filing."
  Subline: "Titles. Tags. Summaries. All on-device."

Screenshot 5 — Daily Recap
  Background: light #FBFAF7
  Device frame: same
  Headline: "One paragraph, every evening."
  Subline: "A reflection of your day, gentle."

Screenshot 6 — Ask Orbit
  Background: light #FBFAF7
  Device frame: same
  Headline: "Chat with your memories."
  Subline: "Orbit answers from your captures."

Screenshot 7 — Time / resurfacing
  Background: light #FBFAF7
  Device frame: same
  Headline: "Your past, on cue."
  Subline: "On This Day · Year in Review · Time Capsules"

Screenshot 8 — Privacy close
  Background: dark #0E0E0E
  No device frame
  Headline (centered, SF Pro Display Bold 72pt, #F4F1EB):
    "Nothing leaves your phone."
  Subline (36pt, #A8A8A8): "On-device AI. No analytics. No ads."
  Below the subline, a 4-row vertical checklist (each row 56pt
  SF Pro Display Medium #F4F1EB, with a 36pt green #3FAE6A
  checkmark glyph as prefix, 28pt vertical spacing between rows):
    ✓  On-device AI
    ✓  End-to-end iCloud
    ✓  No analytics or tracking
    ✓  No data sold or shared

Common padding: 200px top before headlines, 24px between headline
and subline, 120px between subline and device frame, 75px side
margins. Top-align everything (don't vertically center).

Apply all of this, then show me the artboards.
```

---

## Prompt 4 — Drop in the simulator screenshots

Replace the path if your captures are somewhere other than your
Desktop:

```
Place these PNGs from my Mac into the matching device frames:

- ~/Desktop/orbit-app-store/02-capture.png       → screenshot 2
- ~/Desktop/orbit-app-store/04-ai-filing.png     → screenshot 4
- ~/Desktop/orbit-app-store/05-daily-recap.png   → screenshot 5
- ~/Desktop/orbit-app-store/06-ask-orbit.png     → screenshot 6
- ~/Desktop/orbit-app-store/07-year-in-review.png → screenshot 7

Note: my files use the old numbering (01-08) but the assignments
above map them to the new sequence. Use the file names above as the
source of truth.
```

(Note: the file numbering in the seed-data playbook was for the
**old** sequence. If you re-capture under the new sequence,
filenames should be `02-solution-intro.png`, `04-ai-filing.png`,
etc. — match them to the layout slots in this prompt.)

---

## Prompt 5 — Compose the no-device-frame slots (#1, #3, #8)

These three screenshots are pure typography compositions — no app UI
to drop in. Prompt 3 should have already set them up, but if they
look off:

```
Screenshots 1, 3, and 8 should be pure text compositions — no
device frame, no app UI inside them. Verify each:

#1: Dark background, single serif headline centered both axes,
substantial breathing room above and below. Just one element of text.

#3: Aurora blue background, big serif quote centered, tracked
small-caps attribution below. No other content.

#8: Dark background, top-aligned bold sans headline, bold sans
subline below, then a 4-line check-marked list centered horizontally.

If any of those don't match, fix them.
```

---

## Prompt 6 — Export

```
Export all 8 artboards as PNG at 1290 × 2796 to
~/Desktop/orbit-app-store-final/. Name them 01-08 so they sort
correctly in App Store Connect:

  01-problem.png
  02-solution-intro.png
  03-social-proof.png
  04-ai-filing.png
  05-daily-recap.png
  06-ask-orbit.png
  07-year-in-review.png
  08-privacy.png
```

---

## Prompt 7 — Upload to App Store Connect

You need to be signed in to App Store Connect inside ButterKit first
(Settings → App Store Connect → Sign in).

```
Upload the 8 English screenshots from ~/Desktop/orbit-app-store-final/
to App Store Connect for the "Orbit" app, version 1.0, iPhone 6.7"
display size.
```

---

## Localization (later, post-launch)

Once English is shipping cleanly, expand to other markets:

```
Add French, German, Spanish, Japanese, and Portuguese (BR)
localizations to this project. Translate every caption and subline.
Use the App Store Connect language codes: fr, de, es-ES, ja, pt-BR.

When done, export the translated artboards into language-suffixed
folders (e.g. ~/Desktop/orbit-app-store-final/fr/, etc.) and upload
each set to the matching App Store Connect localization.
```

That's the moment the MCP integration earns its keep — what would be
days of manual work in Figma becomes one prompt in ButterKit.

---

## Common gotchas

| Symptom | Fix |
|---|---|
| "I don't see any ButterKit tools" | You're talking to cloud/web Claude, not Claude Desktop. Switch apps. |
| Tools listed but `document_list` errors | ButterKit isn't running. With `--auto-launch` configured it should boot on connect — if not, open ButterKit manually first. |
| Captions look misaligned | The headline + subline padding numbers (200 / 24 / 120 / 75) are the spec. Tell Claude Desktop to re-apply them. |
| Device frame is the wrong model | "Switch all device frames to iPhone 16 Pro Max black titanium." |
| Export wrote wrong dimensions | Confirm the artboard size is 1290 × 2796, not the iPhone 16 Pro Max canvas size (which is 1320 × 2868). 1290 × 2796 is what App Store actually requires. |

---

## Bigger picture

This file lives in the repo so it's version-controlled alongside the
rest of the marketing assets. When you ship a new feature and want
a new screenshot, update the captions here, then paste the relevant
prompt back into Claude Desktop — the visual treatment stays
consistent because everything's specified.
