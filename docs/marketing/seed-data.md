# Sample data + screenshot capture playbook

The simulator (or test device) needs to feel **lived-in** before
screenshots. Empty screens read as a hollow product; one-line stubs
read as fake. The seed below uses paragraph-length captures with
specific, believable detail so when you take screenshots, every
memory looks like something a real person would write down.

A consistent voice helps: I've written everything as if captured by
one person — calm, curious, mid-30s, lives near a coastal city —
over the last two weeks. Tweak any line, but keep the *register*:
no exclamation marks, no LinkedIn-style #motivation, no
embarrassingly personal content.

---

## Before you start

### Device

- **iPhone 16 Pro Max simulator** (or real device of the same size)
  for the 6.7" required size.
- iOS 26 latest.
- Run in **Light mode** unless a screenshot specifies dark.
- Set the simulator status bar to the canonical 9:41, full bars,
  full battery: in terminal:
  ```
  xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4 --wifiBars 3
  ```
  Run this each time the simulator boots.

### Onboarding

Run through onboarding with **Allow** on all four permissions
(Notifications, Mic, Speech, Photos — the only ones we ask for now).
Sign in with Apple if you want the Account row to show your name in
the Settings screenshot. Skip it for a guest-mode shot.

### Theme

Default theme is **Aurora** (cool blue). Leave it on Aurora for
every screenshot — the accent reads as our brand color throughout.

### Recording voice memos efficiently

The voice captures below are 30–45 seconds each. You can:

1. **Read them aloud into the Mac's mic** — natural speech, lets
   Apple's transcriber demonstrate real-world quality.
2. **Use macOS's `say` command** to play the text through speakers
   while the simulator records:
   ```
   say -v Ava -r 175 "$(cat memory-1.txt)"
   ```
   Higher fidelity, no audible "uhms," consistent take-after-take.

Either works. Reading them yourself is faster for v1.

---

## Seed memories (capture in order)

12 captures, ordered roughly the way a real person would build them
up over a week. The order also makes the timeline group believably.

### 1 ▸ Voice note · this morning (Today)

**Type:** Voice
**Capture flow:** Capture → Voice → record while reading the script
below → save

**Transcript script** (~40 seconds spoken naturally):

> Note to self about that bookshop in Roatan — the one with the
> iron spiral staircase up to the second floor. The owner's name
> escapes me. I want to say Mateo, or maybe Mateusz, something
> starting with M. He pulled three novels off the shelf for me and
> made me coffee in this little Bialetti while we talked. The one
> he kept coming back to was an Argentinian writer, I think César
> Aira — a thin paperback with a yellow cover, almost like a
> pamphlet. I promised him I'd order it when I got home and I have
> not. The shop is two blocks off the main square, painted a deep
> teal, and there's a tabby cat that sleeps on the philosophy
> table.

This anchors **Ask Orbit screenshot #5** — the demo question we use
is *"What did the bookshop owner recommend?"* Make sure this memory
exists before that screenshot.

---

### 2 ▸ Text note · today (afternoon)

**Type:** Text

```
Idea for opening the talk next month — start with the Kandinsky line
about the soul being a piano with many strings, and the artist as the
hand that plays it. Bridge to Brian Eno's idea of "scenius" — the
credit for good work doesn't belong to one person, it belongs to a
community, an ecology. The whole point of the talk is that the work
happens at the intersection, not the peak.

Maybe close with the Anne Lamott line about radio towers — that
we're all just transmitting and receiving, and the worst thing we
can do is mistake our station for the signal itself.

I should ask Maria if she'll do the intro. She owes me one.
```

Why: contains the "I should…" pattern that triggers the **Tasks
suggestion engine** (Ask Maria for intro), and reads as a real
working note. Becomes a **Daily Recap highlight**.

---

### 3 ▸ Photo capture · today

**Type:** Photo
**Capture flow:** Capture → Photo → pick a clean image from the
simulator's photo library. The simulator ships with a few stock
photos — the dog or the cat works well.

**Caption (paste into the caption field):**

```
Chispita on the kitchen floor where the late-afternoon light hits at
exactly 4 PM, which means we have about eight minutes before she
rolls over and the show's over. The vet said the new food is helping
with her hip — she's been moving more easily this week, jumping back
up onto the bed without the running start.
```

Why: a real photo caption with personality and continuity (the dog
shows up later in habits/recap). Will tag as `pets` or similar.

---

### 4 ▸ Link capture · today

**Type:** Link
**URL:**

```
https://www.newyorker.com/magazine/2024/02/12/the-new-economics-of-the-arts
```

(any real long-form URL works — Orbit fetches title + preview
automatically.)

**Body / comment to add** (paste into the body field):

```
Read this twice this week, both times angry then thoughtful. The
argument I keep returning to is that subsidy isn't generosity, it's
infrastructure — the same way roads are, the same way libraries
are. Save for the talk. Maybe use the closing paragraph as a
reading.
```

Why: shows the timeline mixing kinds, demonstrates link previews
with attached commentary.

---

### 5 ▸ Voice note · yesterday

To get a memory dated yesterday in the simulator: change the system
clock back one day before capturing, or just accept the timeline
will show today (visual quality is identical).

**Type:** Voice
**Transcript script** (~45 seconds spoken naturally):

> OK so Pamela called this morning — she finally tried that new
> restaurant in the Castro everyone's been talking about. I think
> it's called Florín, with the umlaut maybe, I'm not sure. She went
> with her sister last Thursday and had the lamb tasting menu, said
> the second course was the single best thing she's eaten this year.
> Three different cuts of lamb, all from the same farm in Sonoma, with
> this charred fennel thing on the side that she said she still
> thinks about. We should try to get a reservation for next weekend
> if Daniel and I can find a sitter. She said book three weeks out,
> they don't take walk-ins, and Tuesdays through Thursdays are
> easier than weekends.

This anchors **Ask Orbit screenshot #5** — the question for that
screenshot is *"What did Pamela say about the restaurant?"*

---

### 6 ▸ Text note · 2 days ago

**Type:** Text

```
Reminder to myself: I should write to Dr. Tanaka about the follow-up
in March. The lab results from October were better than expected —
cholesterol came down 28 points, A1C is back in normal range for the
first time in two years. He asked me to send him a quick paragraph
on how the new routine is going before we book the next physical.
Just a few sentences, no need to be fancy.

Things to mention: the running is consistent now (four days a week
since November), I'm sleeping seven hours instead of five, the
afternoon brain fog is gone. Don't mention the coffee.
```

Why: contains the "I should…" pattern that triggers another **Task
suggestion**. Adds a real medical-life thread to the timeline that
makes the user feel like a fully-rounded person.

---

### 7 ▸ Text note · 3 days ago (Gratitude)

**Type:** Text
**Capture flow:** Home → tap the **Gratitude pill** → fill in three
fields with the content below.

If the Gratitude flow has three numbered inputs, paste each section
into the corresponding field. If it falls back to a single text
field, paste the whole thing.

```
1. The afternoon light on the kitchen counter at exactly 4 PM, when
it hits the marble at the right angle and the whole room goes amber
for about twenty minutes. I forgot how much I missed it during the
renovation last year.

2. That my sister called just to say hi — no agenda, no logistics,
no asking for anything. She just wanted to know how I was doing. We
talked for an hour about nothing important and I felt like a whole
person again afterward.

3. Coffee that wasn't even particularly good — the gas station kind,
in a styrofoam cup — but felt earned because it was the first thing
after the morning run and I drank it sitting on the trunk of the car
while the sun came up over the hills.
```

Why: shows the Gratitude flow rendering with a numbered list,
auto-tags as `gratitude`, and adds a beautiful editorial-feeling
memory to the timeline.

---

### 8 ▸ Voice note · 4 days ago

**Type:** Voice
**Transcript script** (~35 seconds):

> Just finished the river loop, second time this week — six and a
> half kilometers, came in just under thirty minutes for the first
> time since the surgery last spring. The herons are back at the
> bend by the old pump house, three of them this morning, standing
> like statues, and the willow has started to bud out which means
> we're maybe two weeks from the bay being warm enough to swim.
> Felt good in my knees, no twinges, which has not been the case
> for most of February. I think the new shoes are working. Also I
> need to remember to thank Daniel for picking those out, the color
> is hideous but the fit is right.

Why: contains the habit-tracking patterns ("ran X km", "running")
— feeds the **Habits tab**. Also has a thank-Daniel mention that
the AI may pick up as a person reference.

---

### 9 ▸ Photo · 5 days ago

**Type:** Photo
**Capture flow:** any landscape or outdoor shot from the simulator
library.

**Caption:**

```
The bay from the bench by the lighthouse, just before sunset. There
were three sailboats out, all heading the same direction, which
never happens. It looked staged. I stood there for ten minutes
after I took this just to make sure I wasn't going to take it for
granted later.
```

Why: depth in the timeline + a beautifully written photo caption
that reinforces the app's calm register.

---

### 10 ▸ Link · last week

**Type:** Link
**URL:**

```
https://every.to/p/the-end-of-organizing
```

(any real essay URL works.)

**Body / comment:**

```
Saving this for later — Olivia mentioned it on the call last night,
said it changed how she thinks about deadlines and to-do lists. The
premise is that organization is a coping mechanism for anxiety more
than a productivity strategy, and most of the systems we build are
just ways to feel in control. Worth thirty minutes when I'm not
exhausted. Read with the phone in another room.
```

Why: Reading List entry, varied timeline content.

---

### 11 ▸ Text note · 2 weeks ago

**Type:** Text

```
I want to read "The Master and Margarita" — Pamela has mentioned it
twice now in different contexts, once when we were talking about
Bulgakov in general and once when she was describing the cat that
lives in the apartment downstairs from her. The translation she
said matters is the Pevear and Volokhonsky one, not the older one
with the simpler prose. She said the cat — Behemoth, in the novel —
is the best character in any novel she's read.

I trust her completely on this. Add to the list. Borrow from the
library first, buy a copy if I love it.
```

Why: contains the "I want to read…" pattern — feeds **Reading
List** with a real-feeling entry.

---

### 12 ▸ Letter to future self · today (Time Capsule)

**Type:** Letter
**Capture flow:** Home → tap the **letter pill** → paste the body
below → set surface date to **6 months from today** → seal it.

```
Dear me, six months from now —

I started something this month that I wasn't sure I could finish,
and by the time you read this you'll either know how it went or
you'll be in the middle of finding out. Either way, I'm writing to
you now because the version of me that started it deserves to be
remembered by the version of you that knows the ending.

Some specifics for context. I'm sitting in the kitchen, it's late,
there's half a mug of cold tea next to the laptop and Chispita is
asleep under the table. The talk is in three weeks. The annual
physical is in March. Daniel's birthday is in April and I haven't
planned anything yet but I will. Maria called yesterday about the
trip and we agreed to push it to June, so don't beat yourself up
about not having gone in May — that was the right call.

What I want you to know — what I'm telling you, future self — is
that the part where you tried, even if it didn't work out, is the
part that matters. I'm proud of that part. Be proud of that part.
Whatever happened next, you didn't make it not have happened. You
started. That counts.

Be gentle with yourself. Eat something. Call your sister.

— me, today.
```

Why: a full letter that reads as a real letter — specific names,
real time markers, emotional substance. The Home screen will show
a "1 sealed" indicator after this. Not used directly in the eight
screenshots, but adds depth if anyone tests time-capsule UI.

---

## Seed tasks

Promote three of the suggestions Orbit auto-generates from the
memories above, then manually add three more.

### Promote 3 suggestions → real tasks

After captures #2, #6, and #11 land, open the **Tasks tab**. The
"Suggestions" section will show:

- **Ask Maria if she'll do the intro for the talk** (from #2)
- **Write to Dr. Tanaka about the follow-up in March** (from #6)
- **Read "The Master and Margarita" (Pevear translation)** (from #11)

Tap each → **Add task**. Set due dates:

- "Ask Maria for intro" → **next Friday**
- "Write to Dr. Tanaka" → **end of next week**
- "Read 'Master and Margarita'" → no due date (it's a reading list
  item, not a deadline)

### Manually add 3 more

Tasks tab → tap **+** → add each:

#### Task 1
- **Title:** `Call dentist about Friday appointment`
- **Due:** Tomorrow
- **Notes:**
  ```
  Confirm the 2:30 slot still works. Need to ask about the crown
  estimate too — Dr. Patel mentioned insurance would cover roughly
  70%, but I want to see the actual number before saying yes. If
  they need to reschedule, push to the following week, not the one
  after — Daniel's parents are in town starting the 19th.
  ```

#### Task 2
- **Title:** `Pick up dry cleaning`
- **Due:** Today
- **Notes:**
  ```
  Two shirts (the white linen and the blue oxford) plus the navy
  suit at the place on 4th. They close at 6 on Wednesdays. Pay
  cash if they have it — they prefer it and there's a small
  discount.
  ```

#### Task 3
- **Title:** `Book flights for spring trip`
- **Due:** Next week
- **Notes:**
  ```
  Daniel and Maria both want to come now, so we're looking at four
  tickets, not two. Aim for the second week of May, ideally landing
  on the 11th. Daniel needs to be back by the 19th for the
  conference. Aim for under $600 a ticket if we go through SFO —
  OAK is fine if SFO doesn't work, but the connection is brutal.
  Use the Chase points first.
  ```

After this, the Tasks tab has:

- 3 promoted from memory suggestions (with linked-memory chips)
- 3 manually added
- A populated **Today** row (Pick up dry cleaning)
- A populated **Upcoming** section (Call dentist tomorrow, others later)
- (Optional) Mark "Pick up dry cleaning" as completed for a
  **Completed** section in the screenshot.

---

## Seed health data (for Daily Recap screenshot)

The simulator's HealthKit is empty by default. To populate:

1. Open the **Health** app in the simulator (it's pre-installed).
2. Browse → **Sleep** → Add Data:
   - Bedtime: yesterday at **11:14 PM**
   - Wake: today at **6:42 AM**
3. Browse → **Steps** → Add Data:
   - Today: **8,432** steps
4. Back in Orbit → Settings → **Health** → toggle on → grant
   access when iOS prompts.

Now the Daily Recap footer renders:
> 🛏 7h 28m asleep · 🚶 8,432 steps

---

## Per-screenshot capture playbook

### 1 ▸ Brand opener (composed in Figma)

No simulator capture. Figma composition:

- Background `#0E0E0E` (solid dark)
- Orbit glyph centered, sized 280 × 280, tinted Aurora `#5A82FF`
- Below the glyph: wordmark **Orbit** at 96 pt SF Pro Display
  semibold, in the off-white `#F4F1EB`
- Below: tagline **A calm second brain for iPhone.** in serif
  56 pt, in textSecondary `#A8A8A8`

---

### 2 ▸ Capture flow

**Navigate:** Tap the FAB (+) on any tab → Capture sheet opens.

**State:**
- Mode switcher: **Text** selected
- Paste this into the body field:
  ```
  Need to remember the name of that bookshop in Roatan — the one
  with the iron spiral staircase. The owner pulled three novels off
  the shelf for me and made me coffee in a little Bialetti while we
  talked. Pretty sure he said the Argentinian one was the best
  starting point.
  ```
- Tap the title bar or scroll the sheet up to **dismiss the
  keyboard** so the screenshot shows the populated body, not a
  keyboard.
- Save button visible at the bottom — don't tap.

**Capture:** ⌘S in simulator.

---

### 3 ▸ Memory Detail with AI metadata

**Navigate:** Timeline tab → tap memory #1 (the bookshop voice note).

**State:**
- Category eyebrow at top — should auto-infer to `travel` or
  `note` (the AI will pick from the content).
- Below: voice waveform + transcript (the full bookshop monologue).
- Further down: the **AI metadata** card with a generated summary
  + 2-3 tag chips like `travel`, `books`, `places`.

**If the AI section is blank** (heuristic fallback hasn't fired
yet), wait 15-30 seconds, pull-to-refresh, or fall back to memory
#2 (the Kandinsky talk note) — the heuristic always tags that one
with the talk/creativity signals.

---

### 4 ▸ Daily Recap

**Prep:** Make sure today has all five of memories #1–4 + #12
captured. The recap generator needs 4+ same-day captures to
produce a substantive paragraph.

**Navigate:** Home tab → tap **Daily Recap** pill.

**State:**
- Day number (today's date) in Aurora blue, 168 pt
- Day-of-week in serif (e.g. "Tuesday")
- Month + year in tracked small caps (e.g. "MAY 2026")
- Narrative paragraph (auto-generated)
- Stats row: **5 captures · Reflective** (or whatever mood the AI
  picks)
- Sleep + steps footer (from the health data you seeded)

**Capture below the navigation bar** so the inline title doesn't
clip the top of the recap.

---

### 5 ▸ Ask Orbit

**Navigate:** Home tab → tap **Ask Orbit** pill.

**State:**

1. Tap the question field, type:
   ```
   What did Pamela say about the restaurant?
   ```
2. Hit submit. Wait for the answer to render.
3. The screenshot should show:
   - Your question at the top
   - The answer in serif, 2–3 sentences referencing the lamb
     tasting menu, Florín, the Sonoma farm, and the
     reservation timing
   - **Sources** section below with the Pamela voice note (memory
     #5) as a clickable chip

**If the answer is generic** ("I couldn't find anything…"),
re-capture memory #5 with the phrasing closer to: *"Pamela said the
new restaurant Florín in the Castro is incredible — she had the
lamb tasting menu with her sister, three cuts from the same Sonoma
farm. We should book three weeks out."* Then re-ask.

---

### 6 ▸ Share card preview

**Navigate:** Open memory #2 (the Kandinsky talk note) → tap the
share button (top-right toolbar).

**State:**
- iOS share sheet appears with the rendered share card filling the
  preview area
- The card shows: Orbit brand mark at top, the talk-opener body in
  serif as the hero text, attribution block at the bottom

Memory #2 is the right pick because its content reads beautifully
on the card. Memory #5 (Pamela/restaurant) is a fine alternative
for a more conversational tone.

**Alternative:** capture the rendered card image directly. Open
Daily Recap → tap share → save the card to Photos → import and
frame it standalone in Figma. This avoids the system share-sheet
UI and gives you a cleaner shot.

---

### 7 ▸ Year in Review

**Prep:** Since we removed the dev-mode "Preview Year in Review"
affordance in the release-readiness pass, the simplest way to force
this surface for screenshot purposes is to time-travel the
simulator clock:

1. Simulator → **Features → Time Travel → Tomorrow** (repeat until
   the clock reaches **December 28**).
2. Quit and re-launch Orbit.
3. Home → the **Year in Review** banner appears.
4. Tap the banner.

**State:**
- 220 pt year glyph in Aurora blue
- "[N] memories — a year in motion." in serif as the headline
- Sparkline below showing monthly counts
- Two or three label/value rows (Top category, Recurring name)

The year glyph is the dominant visual. Frame so it gets full top
placement in the screenshot.

After capturing, **revert the simulator clock to the real date**
before continuing.

---

### 8 ▸ Privacy close (composed in Figma)

No simulator capture. Figma composition:

- Background `#0E0E0E`
- Centered Orbit glyph at 120 × 120, accent color
- Below, a stacked checklist in SF Pro Display, each row 56 pt,
  weight 500:
  ```
  ✓  On-device AI
  ✓  End-to-end iCloud
  ✓  No analytics or tracking
  ✓  No data sold or shared
  ```
- Checkmark glyphs 36 pt in `OrbitColor.success` (`#3FAE6A`)
- 28 pt spacing between rows
- Foreground text in off-white `#F4F1EB`

---

## Common gotchas

**The AI section is blank in Memory Detail.**
Enrichment runs in the background after capture. Give it 15–30
seconds. If it still hasn't run on the simulator (Apple Intelligence
unavailable), the heuristic fallback still fills tags + category —
just make sure your memory text contains a clear category-signaling
word: `ran` (fitness), `Pamela said` (people), `I should` (task),
`want to read` (reading), `grateful for` (gratitude).

**The Daily Recap narrative reads generic.**
The recap generator works from the day's captures. If you've only
saved 1–2 things today, the prose will be sparse. Make sure today
has at least 4–5 captures from the seed list before opening Daily
Recap. The order: capture memories #1–4 and #12 today, then open
the recap.

**Voice transcripts come out wrong or empty.**
The simulator records from your Mac's microphone. If you're in a
noisy room or speaking too fast, Speech Recognition will hallucinate.
Two fixes: (a) use the `say -v Ava -r 175 "…"` approach to play the
transcript through your Mac speakers while the simulator records,
or (b) record a quiet 5-second placeholder and edit the memory's
transcript field in the detail view if the in-app editor allows it.
For v1 screenshots, (a) is foolproof.

**Status bar shows 9:41 but the wrong battery / signal.**
Re-run the `xcrun simctl status_bar booted override …` command from
the "Before you start" section any time the simulator boots.

**Year in Review doesn't appear after time-traveling the clock.**
The banner gates on whether the target year was already dismissed.
If you previously dismissed it, wipe content + settings before the
time-jump (Simulator → Device → **Erase All Content and Settings**),
re-seed memories, then time-travel.

**Capture sheet keyboard covers the body in screenshots.**
After typing, tap the title bar or drag the sheet up slightly to
dismiss the keyboard. The screenshot should show the input area
fully populated with content visible.

---

## After capture

Move all eight PNGs into a single folder
(e.g. `~/Desktop/orbit-app-store/`). Filename them so the App Store
upload UI orders them correctly:

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

App Store Connect → **Media** → drag all eight in at once. The
order shown in the listing matches the filename sort.
