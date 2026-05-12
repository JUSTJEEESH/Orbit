# Sample data + screenshot capture playbook

The simulator (or test device) needs to feel **lived-in** before
screenshots. Empty screens read as a hollow product; over-populated
screens read as theatrical. Below is a tight set of seed memories and
tasks designed to make every shot in
[`screenshots.md`](./screenshots.md) look natural — about 30 minutes
of setup, max.

A consistent voice helps: I've written everything below as if it
were captured by one person — calm, curious, mid-30s — over the
last few weeks. You can tweak any line, but keep the *register*: no
exclamation marks, no LinkedIn-style #motivation, no embarrassingly
personal content.

---

## Before you start

### Device

- **iPhone 16 Pro Max simulator** (or real device of the same size)
  for the 6.7" required size.
- iOS 26 latest.
- Run in **Light mode** unless a screenshot specifies dark.
- Set the simulator status bar to the canonical 9:41, full bars,
  full battery: in Xcode, **Features → Toggle Software Keyboard**
  to dismiss, then `xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4 --wifiBars 3`
  from terminal.

### Onboarding

Run through onboarding once with **Allow** on all four permissions
(Notifications, Mic, Speech, Photos — the only ones we ask for now).
Sign in with Apple if you want the Account row to show a name in
the Settings screenshot; skip it for a guest-mode shot.

### Theme

Default theme is **Aurora** (cool blue). For Year in Review, **Daily
Recap**, and **Ask Orbit** screenshots, leave it on Aurora — the
accent reads as our brand color in every shot.

---

## Seed memories (capture these in order)

12 captures, ordered roughly the way someone would build them up over
a real week. The order also makes them appear in a believable
timeline grouping.

### 1 ▸ Voice note · this morning (Today)

**Type**: Voice
**Capture flow**: Capture sheet → Voice → record 18 seconds → save
**Transcript** (read this into the mic):

> "Note to self — that bookshop in Roatan, the one with the iron
> spiral staircase. I want to remember the owner's name. He
> recommended that novel by the Argentinian writer. The one with the
> coffee."

This anchors the **Ask Orbit demo** later — the question we use is
"What did the bookshop owner recommend?"

---

### 2 ▸ Text note · earlier today

**Type**: Text
**Capture flow**: Capture → Text → type, save

> Idea for the talk: open with the Kandinsky quote about the soul
> being a piano with many strings. Then the Brian Eno bit about
> "scenius" — credit goes to a community, not an individual.

Why: shows the timeline rendering a thoughtful "creative work" note.
This becomes one of the **Daily Recap highlights**.

---

### 3 ▸ Photo capture · today

**Type**: Photo
**Capture flow**: Capture → Photo → pick any clean image from the
simulator's photo library (the simulator ships with a few stock
images — the dog or the lake works well)
**Caption**: leave blank

The AI will write a caption automatically. Use the **dog image** if
you have it — it categorizes as `pets` and that becomes a nice
category tint later.

---

### 4 ▸ Link capture · today

**Type**: Link
**Capture flow**: Capture → Link → paste the URL below → save

```
https://www.newyorker.com/magazine/2024/02/12/the-new-economics-of-the-arts
```

(or any real New Yorker / Atlantic article URL — Orbit fetches the
title and image preview automatically)

Why: shows the timeline mixing kinds (voice, text, photo, link).
This becomes the "Reading List" entry implicitly because it's a
link.

---

### 5 ▸ Voice note · yesterday (00:01 yesterday)

To get a memory dated yesterday in the simulator, either:
- Change the simulator system clock back one day before capturing, or
- Capture today and just accept the timeline will show today; the
  visual quality is the same.

**Type**: Voice
**Transcript** (15s):

> "Pamela said the new restaurant in the Castro was incredible — she
> had the lamb tasting menu with her sister. We should try to go
> next weekend."

This anchors **Ask Orbit screenshot #5** — question is "What did
Pamela say about the restaurant?"

---

### 6 ▸ Text note · 2 days ago

**Type**: Text

> Reminder to myself: I should write to Dr. Tanaka about the follow-up
> in March. The lab results were better than expected.

Why: contains the "I should…" pattern that triggers the **Tasks
suggestion engine**, which we want to see populated in the Tasks
screenshot.

---

### 7 ▸ Text note · 3 days ago

**Type**: Text

> Three things I'm grateful for today —
>   1. The afternoon light on the kitchen counter at 4pm.
>   2. That my sister called just to say hi.
>   3. Coffee that wasn't even particularly good but felt earned.

Why: shows the **Gratitude** flow rendering with the numbered list
formatting. Will be tagged automatically as `gratitude`.

---

### 8 ▸ Voice note · 4 days ago

**Type**: Voice
**Transcript** (12s):

> "Ran the river loop again. Six and a half kilometers, sub-thirty
> for the first time. Beautiful morning, the herons were back."

Why: contains the habit-tracking patterns ("ran X km") — feeds the
**Habits tab** with a believable activity.

---

### 9 ▸ Photo · 5 days ago

**Type**: Photo
**Caption**: leave blank — let the AI infer it

Use a generic outdoor / city / coffee shot from the simulator
library. This adds a photo memory deeper in the timeline.

---

### 10 ▸ Link · last week

**Type**: Link
**URL**:

```
https://every.to/p/the-end-of-organizing
```

Or any real essay URL. The link memory shows up in **Reading List**
as a "want to read" entry if you preface it with "want to read".
For this one, leave the body blank.

---

### 11 ▸ Text note · 2 weeks ago

**Type**: Text

> I want to read "The Master and Margarita" — Pamela mentioned it
> twice now in different contexts. The translation she said matters
> is the Pevear one.

Why: contains the "I want to read X" pattern — feeds **Reading
List** with a believable entry.

---

### 12 ▸ Letter to future self · today (Time Capsule)

**Type**: Letter
**Capture flow**: Home → tap the **letter pill** → write the body
below → set surface date to **6 months from today** → seal it.

> Dear me, six months from now —
>
> I started something this month that I wasn't sure I could finish.
> By the time you read this, you either did, or you didn't, and
> either way I want you to know I'm proud of the part where I
> tried.
>
> Be gentle.

Why: shows the **Letter / Time Capsule** flow. The home screen will
show a "1 sealed" indicator after this. Not used directly in the 8
screenshots, but adds depth if anyone looks closely.

---

## Seed tasks

6 tasks, generated naturally if you capture memories #2 + #6 (the
"I should…" patterns will surface them as task suggestions). To
fill the Tasks tab beyond suggestions:

### Promote 3 suggestions → real tasks

After capture #6 + #11, open the **Tasks** tab. You'll see them as
**Suggestions**. Tap each → **Add task**.

After capture #2, the talk-opener idea: tap the suggestion → **Add
task**, set due date to **next Friday**.

### Manually add 3 more

From the Tasks tab → tap **+** → add each with the due dates shown:

| Title                                    | Due       | Notes                                |
|------------------------------------------|-----------|--------------------------------------|
| Call dentist about Friday appointment    | Tomorrow  | Confirm 2:30 still works             |
| Pick up dry cleaning                     | Today     | _(leave notes blank)_                |
| Book flights for spring trip             | Next week | Daniel + Maria want to come now too  |

Now the Tasks tab has:
- 3 promoted from memory suggestions
- 3 manually added
- A **Today** section (Pick up dry cleaning)
- An **Open** section (the rest)
- (Optional) Mark "Pick up dry cleaning" as completed for a
  **Completed** section to appear

---

## Seed health data (for Daily Recap screenshot)

If the simulator's HealthKit is empty, the bottom of the Daily Recap
won't show the sleep + steps line. To populate it:

1. Open the **Health** app in the simulator.
2. Browse → **Sleep** → Add Data:
   - Bedtime: yesterday at 11:14 PM
   - Wake: today at 6:42 AM
3. Browse → **Steps** → Add Data:
   - Today: **8,432** steps
4. Open Orbit → Settings → **Health** → toggle on → grant access.

Now the Daily Recap footer reads:
> 🛏 7h 28m asleep · 🚶 8,432 steps

---

## Per-screenshot capture playbook

### 1 ▸ Brand opener (composed in Figma)

No simulator capture needed. This is a Figma composition:
- Solid dark background `#0E0E0E`
- Orbit glyph centered, sized 280×280, tinted Aurora `#5A82FF`
- Wordmark "Orbit" centered below, 96pt SF Pro Display semibold
- Tagline "A calm second brain for iPhone." in serif 56pt, textSecondary

---

### 2 ▸ Capture flow

**Navigate**: Tap the FAB (+) on any tab → Capture sheet opens.
**State**:
- Mode switcher: **Text** selected
- Body field: paste this in (it reads as a natural mid-thought
  capture):

> Need to remember the name of that bookshop in Roatan — the owner
> gave me a coffee and a hardcover I still need to crack open.

- Save button visible at bottom (don't tap it).
- Keyboard hidden — tap the body field once then tap somewhere else
  to dismiss the keyboard so it doesn't dominate the screenshot.

**Capture**: ⌘S in simulator → save PNG.

---

### 3 ▸ Memory Detail with AI metadata

**Navigate**: Timeline tab → tap memory #1 (the voice note about
the bookshop).
**State**:
- The header shows the category eyebrow (will be auto-inferred —
  likely `travel` or `note`)
- Below: voice waveform + transcript ("Note to self — that
  bookshop in Roatan…")
- Further down: an **AI metadata** card showing the generated
  summary + 2-3 tag chips

**If the AI section is empty** (heuristic fallback didn't fire
quickly enough), pull-to-refresh the screen or wait 10 seconds —
enrichment runs in the background. If it's still empty, switch to
memory #2 (the Kandinsky talk note) instead, which heuristic
extraction always tags.

---

### 4 ▸ Daily Recap

**Navigate**: Home tab → tap **Daily Recap** pill.
**State**:
- The recap should show:
  - Day number (today, e.g. 12) in the accent color, oversized
  - Day-of-week in serif
  - A narrative paragraph (auto-generated; if it looks generic, just
    accept it — the screenshot is about the typography)
  - Stats row: **5 captures · Reflective** (or whatever mood AI picks)
  - Sleep + steps footer (from the health data you seeded)

**Tip**: capture just below the navigation bar so the "Daily Recap"
inline title doesn't cut off. The screenshot should bleed the
content slightly into the bottom safe area.

---

### 5 ▸ Ask Orbit

**Navigate**: Home tab → tap **Ask Orbit** pill.
**State**:
- Tap the field, type:
  > What did Pamela say about the restaurant?
- Hit submit. Wait for the answer to render.
- The screenshot should show:
  - Your question at the top
  - The answer in serif, 2-3 sentences referencing the lamb tasting
    menu / Castro detail
  - **Sources** section below with 1-2 memory chips linked to the
    relevant captures

**Tip**: if the AI says "I couldn't find anything related," capture
the voice note (#5) again with the Pamela phrasing more verbatim,
then re-ask.

---

### 6 ▸ Share card preview

**Navigate**: Open any memory's detail view → tap the share button
(top-right toolbar).

**State**:
- iOS share sheet appears with the rendered share card filling the
  preview area
- The card shows: Orbit brand mark at top, hero quote/summary in
  serif, attribution block at bottom

**Tip**: pick memory #2 (the Kandinsky talk note) — its content
reads beautifully on the card. Or memory #5 (Pamela / restaurant)
for a more conversational tone.

Alternative: take the screenshot of the rendered card itself by
opening Daily Recap → tap share → save the card to Photos → import
and frame it standalone. This avoids the system share sheet UI.

---

### 7 ▸ Year in Review

**Navigate**:
- Open **Settings → About** _(in DEBUG builds, the "Preview Year in
  Review" affordance used to be here — we removed it in the
  release-readiness pass)_.
- Since we removed the dev preview, the simplest way to force the
  Year in Review surface for screenshot purposes is to change the
  simulator clock to **December 28** for a moment:
  1. Simulator → **Features → Time Travel → Tomorrow** (repeat
     until December 28).
  2. Restart Orbit.
  3. Home → Year in Review banner appears → tap it.

**State**:
- 220pt year glyph in Aurora blue
- "[N] memories captured…" headline in serif
- Sparkline below
- Two or three label/value rows (Top category, Recurring name,
  etc.)

**Tip**: the year hero is the dominant visual. Frame the screenshot
so it gets full top placement.

After capturing, **revert the simulator clock** to the real date so
subsequent screenshots aren't dated weird.

---

### 8 ▸ Privacy close (composed in Figma)

No simulator capture. Figma composition:
- Dark background `#0E0E0E`
- Centered Orbit glyph at 120×120, accent color
- Below, a stacked checklist in SF Pro Display:
  - ✓ On-device AI
  - ✓ End-to-end iCloud
  - ✓ No analytics or tracking
  - ✓ No data sold or shared
- Each row 56pt, weight 500, textPrimary
- Checkmark glyphs 36pt in `OrbitColor.success` (a quiet green ~`#3FAE6A`)
- Generous spacing between rows (~28pt)

---

## Common gotchas

**The AI section is blank in Memory Detail.**
Enrichment runs in the background after capture. Give it 15–30
seconds. If it still hasn't run on the simulator (Apple Intelligence
unavailable), the heuristic fallback still fills tags + category —
make sure your memory text contains a clear category-signaling word
like "ran" (fitness), "Pamela said" (people), "I should" (task),
"want to read" (reading), "grateful for" (gratitude).

**The Daily Recap narrative reads generic.**
The recap generator works from the day's captures. If you've only
saved 1–2 things today, the prose will be sparse. Make sure today
has 4–5 captures from the seed list before opening Daily Recap.

**Status bar shows 9:41 but the wrong battery / signal.**
The override command from the "Before you start" section sets all
three (time, battery, cellular). Re-run it any time the simulator
re-launches.

**Year in Review doesn't appear after time-traveling the clock.**
The banner gates on `shouldOfferYearInReview()` which checks if the
target year was already seen. If you previously dismissed it,
re-install the app or wipe content + settings before the time-jump.

**Capture sheet keyboard covers the body in screenshots.**
After typing, tap the title bar or scroll the sheet up slightly to
dismiss the keyboard. The screenshot should show the empty
input-area state with content already populated.

---

## After capture

Move all eight PNGs into a single folder (e.g. `~/Desktop/orbit-app-store/`).
File-name them in order so the App Store upload UI orders them
correctly:

```
01-brand-opener.png
02-capture.png
03-ai-filing.png
04-daily-recap.png
05-ask-orbit.png
06-share-card.png
07-year-in-review.png
08-privacy.png
```

App Store Connect → Media → drag all eight in at once. The order
shown in the listing will match the filename sort.
