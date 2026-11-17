# Orbit 2.0 — Master Plan (for one-go approval)

Prepared Nov 17, 2026, from three research tracks: what users want and nobody
delivers, Apple's newest platform features, and what award-winning apps do
differently. Combined with a screen-by-screen review of Orbit's code.

**Status today:** the data-safety foundation and the first wave of 2.0
features are built and pass CI: 98 automated tests, including a real 1.x →
2.0 upgrade test. They're listed at the end. Everything below is new.

**Legend:**
- ★ = no competitor does this well (research-backed)
- 🍎 = new Apple tech that helps get featured
- **[27]** = iOS 27 only. iOS 26 users get a graceful fallback; Orbit still
  supports iOS 26.

---

## The big idea: memory that *acts*

Every competitor either **stores** notes (Apple Journal, Day One, Bear),
tracks **work** commitments in the cloud (Vortyx, Chiefly), or is a
**single-purpose** ADHD tool (Tiimo, BrainSort, PutIt). Nobody combines a
five-second brain dump with a memory that **acts at the right moment**: the
right place, person, time or promise. And nobody does it privately, on the
iPhone. That's Orbit 2.0's position.

> Timely: Meta bought Limitless/Rewind. Its Mac app stopped capturing in
> Dec 2025 and Pendant support ends around now. Those users want a private
> "remember my life" app. *"Your iPhone already remembers."*

---

## A. Capture: the fastest place to put a thought

1. **Capture from anywhere** 🍎: a Control Center button, a Lock Screen
   button and the Action Button start voice capture instantly
   (`AudioRecordingIntent` + Live Activity). Interactive widgets with
   record/type buttons. StandBy-ready.
2. **Hold + to talk**: press and hold the capture button to record, release
   to save. The haptic gently swells while recording. No sheet, no mode.
3. **Live transcription while you talk** 🍎: Apple's new on-device
   `SpeechAnalyzer` (iOS 26), with no time limit and fully offline. Audio is
   saved first, so a failed transcription never loses a recording, fixing
   the #1 complaint about Voicenotes and AudioPen.
4. **★ Search inside voice notes, and jump to the moment**: find a word
   said in any recording, and playback jumps straight to it. Voicenotes
   users publicly complain they can't search transcripts.
5. **★ Screenshot inbox that acts and expires**: Orbit reads recent
   screenshots (with permission). A ticket becomes a dated memory plus a
   reminder and archives itself after the date. A recipe goes into a
   collection. A receipt gets filed. Screenshot-organizer apps only sort;
   none act.
6. **Lock Screen camera capture** re-enabled for photo and document
   memories.
7. **Apple Watch upgrades**: a capture control on the Watch, Smart Stack
   card, Live Activity on the wrist.

## B. Memory that acts — the differentiators

8. **★ Promise Ledger**: "I told Sam I'd send the photos" becomes an open
   promise (who, what, a soft due date). It's surfaced gently and closed
   with one tap. A wave of 2026 apps do this for work email; nobody does it
   for your life, privately, from voice.
9. **★ Place and person reminders**: "Remind me at Mom's" or "next time I'm
   with Alex." Research shows ADHD minds do far better with event cues than
   clock cues. Note apps refuse to add reminders; reminder apps don't hold
   memories. Uses Apple's region monitoring and calendar attendees.
10. **★ Before-you-meet briefing**: 30 minutes before a calendar event with
    someone, a quiet card shows your last topics, their kids' names, open
    promises and the gift idea you saved. Mem has this but cloud-only and
    work-only. Orbit's is personal and on-device.
11. **★ "Where did I put it?"**: say or snap "passport is in the blue box,
    top shelf." Later, "Where's my passport?" in Ask Orbit or Siri shows the
    answer and the photo. Today this only exists in isolated single-purpose
    apps.
12. **★ Time-since**: "Last talked to Dad 23 days ago," "Plant watered 9
    days ago," worked out automatically from what you capture. Shown on
    People and Habit pages and in a widget. A gentle aid for time
    blindness.
13. **Weekly Review**: a calm Sunday sheet: open loops and promises, who
    you talked about most, your three best moments, one memory worth
    revisiting.
14. **★ Welcome back, never streaks**: no streak to break. After time away,
    Orbit opens with a calm "here's what's still open" instead of guilt.
    Day One users petition to hide streaks; ADHD users abandon apps over
    them.

## C. Intelligence: smart, trustworthy, invisible

15. **★ Answers you can trust**: every Ask Orbit sentence cites the memory
    it came from (tap to open). Orbit says "I don't know" rather than
    guessing. Follow-up questions ("and what did she say after?") keep
    context.
16. **Spotlight and Siri know your memories** 🍎: every memory becomes a
    Spotlight-indexed App Entity. Siri, Shortcuts and Spotlight can find and
    open memories. Visual Intelligence integration ("find memories like
    this photo").
17. **New Siri, ready on day one** 🍎 **[27]**: adopt Apple's Siri-facing
    Notes schema, plus prototype "app skills" for the new personal-context
    Siri. Apple only allows these in App Store builds from spring 2027, so
    2.0 ships the foundation and turns them on as soon as Apple opens
    submissions.
18. **Collections that make themselves**: Orbit notices clusters ("Roatán
    trip," "Kitchen renovation") and offers to group them. No folders.
19. **Deeper Ask on iOS 27** 🍎 **[27]**: Apple's Private Cloud Compute
    model (32K context, private, free for small businesses) for questions
    across many memories and for Weekly Review, built on Apple's new
    Spotlight retrieval tool. Falls back to on-device. *Requires an Apple
    entitlement you apply for (I'll give you the steps).*
20. **Photos and receipts understood** 🍎: on-device text reading on iOS 26;
    on iOS 27 the model looks at the image itself (a receipt total, a
    whiteboard, a label).
21. **★ Day recap from what your phone already knows** 🍎: Apple's Journaling
    Suggestions (places you went, photos, workouts, songs, people), chosen
    by the user, enrich the Daily Recap. Nothing is recorded continuously.
    A private "life log lite" for Rewind/Limitless refugees.

## D. Look and feel: calmer and more tactile than anyone

22. **Native iOS 26 Liquid Glass** 🍎: system tab bar that minimizes on
    scroll, Search as its own tab, and the capture button morphing with the
    tab bar. Glass only on controls; content stays solid (Apple's
    guidance and Orbit's rules). Ready for the iOS 27 design, which removes
    the opt-out.
23. **Signature motion pass**:
    - a capture button that morphs into the recorder
    - mic → stop → ✓ symbol transitions
    - numbers that roll
    - quiet "thinking" dots in Ask
    - Orbit's AI tags fade in once ("Orbit understood")
    - springs everywhere (replacing 11 non-spring animations found)
24. **Satisfying moments**: task completion with a bounce, a ring pulse,
    a success haptic and a beat before the row moves. The same care on
    saving a memory. (What made Tiimo App of the Year and (Not Boring)
    beloved.)
25. **Haptics done right**: move to SwiftUI's declarative haptics so every
    buzz matches a real state change and respects system settings.
26. **A calmer Home**: today Home stacks up to 8 cards. 2.0 shows one
    contextual surface at a time (morning: On This Day; evening: Recap;
    Sunday: Weekly Review), with a skeleton while loading instead of the
    "empty" flash.
27. **Personal search start screen**: suggestions from your own people,
    places and recent searches, replacing the hard-coded demo examples.
    Native search scopes and suggestions.
28. **Power gestures**:
    - swipe right to pin or make a task
    - long-press for a preview with quick actions
    - drag a memory onto a day to resurface it or reschedule
29. **Gentle tips (TipKit)**: one tip at a time for hold-to-talk,
    swipe-to-pin and Ask, instead of always-visible buttons.
30. **Empty states with personality**: warm, specific copy and one clear
    action.
31. **Live Activity with a stop button**: stop a long recording from the
    Lock Screen or Dynamic Island, with elapsed time and transcription
    progress.
32. **Accessibility that editors notice**:
    - VoiceOver rotors (Days, Voice memories, Connected)
    - layouts that stack vertically at the largest text sizes
    - every fixed font size made scalable (30 places)
    - 44-pt touch targets (the task checkbox is 22 pt today)
    - cross-fades instead of motion for Reduce Motion
33. **Speed at any size**: Timeline loads in pages, Home loads in parallel,
    and search embeddings are kept off the main list path. It stays instant
    with 10,000 memories.

## E. Onboarding and growth

34. **First memory in 30 seconds**: onboarding includes a real first voice
    capture, then shows Ask Orbit answering about it. (Apple's 2026
    Interaction award praised onboarding specifically.)
35. **Paywall at the end of onboarding with a 14-day trial** (new users
    only). Lifetime stays visible. Existing subscribers and lifetime owners
    keep everything.
36. **Fairer free tier** (research: limiting capture or recall drives 1-star
    reviews):
    - **Free stays unlimited:** capture, search and basic Ask.
    - **Pro:**
      - Promise Ledger
      - place and person reminders
      - briefings
      - Weekly Review
      - deep Ask
      - photo and audio sync
      - long voice notes
      - full Year in Review

    *Decision for you (see below).*
37. **Shareable cards** for Ask answers and Weekly Review.
38. **Spanish and Portuguese app text**: most paying customers are outside
    the US. I translate; a native speaker should proofread.
39. **iPad, Mac and iPhone Duo** 🍎:
    - **iPad:** a resizable layout (required by the iOS 27 SDK anyway).
    - **Mac:** a native Mac app.
    - **iPhone Duo:** layout for Apple's new foldable, a strong featuring
      hook.

## F. Trust

40. **Photos and recordings sync through iCloud**: recordings compressed
    about 10×, so iCloud storage isn't eaten up.
41. **Mood with Apple Health (optional)**: log how a moment felt; it's saved
    to Health's State of Mind (with permission) and shows in recaps.

## Optional — research says demand is unproven (recommend 2.1)

42. **Focus companion**: "Taxes for 25 minutes." A Live Activity keeps you
    company, checks in kindly, and logs it as a memory (solo "body
    doubling").
43. **Family stories**: voice prompts for a parent or grandparent; their
    real voice is kept with the transcript and can be shared or sealed as a
    time capsule. Needs shared iCloud records.

---

## Decisions for you

1. **Approve A–F (items 1–41)?** My recommendation: yes.
2. **Items 42–43 (optional):** include now, or 2.1?
3. **Free tier (item 36):** move to "unlimited capture, search and basic
   Ask; Pro = the advanced features"? Research strongly favors this, but it
   changes today's limits (3 recaps and 10 asks a week).
4. **Prices:** keep $2.99 / $29.99 / $79.99, or raise yearly to $39.99 for
   new buyers (rivals charge 2–4× more)? Existing subscribers are never
   affected.

## What I need from you along the way

- **Apply for Private Cloud Compute** (item 19), when I send the steps; it's
  a short form on Apple's developer site.
- **Journaling Suggestions capability** (item 21): a checkbox in Xcode;
  I'll walk you through it.
- **Native-speaker proofread** of the Spanish and Portuguese text.
- **TestFlight testing** at each milestone (checklists provided).
- New App Store screenshots at the end (Phase 0 copy is ready).

## How we build it without breaking anything

The same rules as so far:
- **Data changes only add fields.** 2.0's database version hasn't shipped
  yet, so any new fields fold into it (one upgrade step, not several), and
  the real-1.x upgrade test grows to cover them.
- **Every change goes through CI** (build plus all tests) before you test.
- **Every new permission is optional.** Location, Calendar, Photos and
  Health are asked for only when you first use the feature, with a plain
  reason.

**Milestones** (each one a TestFlight build you can try):
1. **Capture + Look and feel** (A, D): the biggest visible jump.
2. **Memory that acts** (B).
3. **Intelligence + Siri** (C).
4. **Onboarding, growth and trust** (E, F) → the App Store 2.0 release.

**Honest timing:** this is a large release, many build sessions plus your
testing at each milestone. Shipping it as one App Store update is fine;
milestones just keep each step testable and safe.

---

## Already built for 2.0 (passing CI)

**Data safety:**
- versioned schema with a tested 1.x upgrade
- pre-upgrade snapshot
- Recovery screen
- Siri-capture rescue
- Watch transcript repair
- launch maintenance for interrupted processing

**Features:**
- Recently Deleted + Undo
- Edit memories
- Export and Import (Day One, text, Orbit)
- opt-in iCloud sync (text and metadata) + What's New
- Face ID lock
- Worth-remembering notification
- People & Places
- natural-language reminders
- widget nudge
- smarter review prompts and a Rate Orbit row
- Year in Review deep link

**Fixes:**
- search relevance
- enrichment race
- duplicate Safari imports
- media row bloat
- Recent widget blank
- incomplete account wipe
- Ask quota charged on failure
- large-photo crash
- capture button covering rows
- launch-order bug
- two broken test files
