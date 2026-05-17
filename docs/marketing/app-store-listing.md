# Orbit — App Store Listing

Drop these strings directly into App Store Connect. Character counts in
parentheses are within Apple's limits.

---

## App Name (30 char max)

```
Orbit — AI Second Brain
```
(22 chars)

> Rationale: leads with the brand, then hits two of the highest-volume
> search phrases in the journaling/memory space — "AI" and "second
> brain." The em-dash reads cleaner than a colon and matches Apple's
> own first-party naming conventions (e.g., "Notes — Quick Capture").

---

## Subtitle (30 char max)

```
Journal, voice notes & recap
```
(28 chars)

> Rationale: backs up the name with three more high-intent keywords
> Apple's algorithm will fold into matching. "Journal" + "voice notes"
> cover the dominant search phrases competing with Day One and
> Apple Journal; "recap" is a low-competition long-tail that maps
> directly to Orbit's signature surface.

---

## Keywords (100 char max, comma-separated, no spaces)

```
memory,memo,gratitude,mood,habit,tracker,reflect,mindful,wellness,thoughts,daily,captures,lifelog
```
(97 chars)

> Rationale: only words that aren't already in the name or subtitle
> (Apple indexes those automatically and counts duplicates as wasted
> field space). Mix of high-volume terms ("memory", "gratitude",
> "mood", "tracker") and niche/long-tail ("lifelog", "captures") so
> Orbit ranks for both broad and intent-rich queries.

---

## Promotional Text (170 char max, editable without resubmission)

```
Capture life as it happens. Orbit organizes the rest — quietly, on-device, with Apple Intelligence.
```
(98 chars)

> Rationale: promotional text shows above the description on the App
> Store page. Lead with the promise, end with the trust signal
> ("on-device, with Apple Intelligence") that converts privacy-aware
> buyers.

---

## Description (4000 char max)

```
Orbit is a second brain for the things you don't want to forget — moments, ideas, voice notes, photos, the link you saved at 2am. Everything lives in one calm timeline that AI quietly organizes for you.

No tagging. No folder hierarchy. No notification fatigue. Just capture, and let Orbit find the meaning later.

— WHAT YOU GET —

• Capture anything in seconds — text, voice memos, photos, links, screenshots, even a place. Apple Intelligence handles the rest: titles, tags, summaries, categorization.

• Daily Recap — a one-paragraph reflection of your day, generated each evening from the moments worth revisiting.

• Ask Orbit — chat with your own memories. Ask "what did Pamela say last weekend?" or "what was the restaurant in Roatan?" Orbit answers from your captures, never from the cloud.

• On This Day, Year in Review, Time Capsules — Orbit surfaces your past at the right moment.

• Tasks that find themselves — write "I should call mom tomorrow" anywhere in a memory and Orbit suggests it as a task. Promote what you mean. Ignore what you don't.

• Reading list & habit tracking — captures like "I want to read…" or "ran 5k" land in their own surfaces, quietly tracked over time.

• Beautiful share cards — turn a memory, a Daily Recap, or a Year in Review into an editorial-quality image, ready for Stories, iMessage, or just keeping.

• Privacy by design — On-device AI via Apple Intelligence. Voice transcribed locally. Sleep + steps stay on your phone. iCloud sync runs end-to-end. Nothing is sold. Nothing is shared.

— DESIGNED FOR APPLE —

Lock Screen camera capture · Apple Watch voice notes · Siri Shortcuts · Spotlight search · Home Screen widgets · Safari extension · Share extension · iOS Reminders & Calendar sync · HealthKit sleep + steps in your Daily Recap

— PRO —

A monthly or annual subscription unlocks unlimited captures and the full AI surfaces. Cancel anytime from Settings → Subscription.

— WHY WE BUILT IT —

Journaling apps ask too much. Note apps forget everything. The things we want to remember keep slipping away.

Orbit is what we wished existed — a calm, native, private place where life can quietly accumulate, and an AI that helps you find what matters without taking over the experience.

Welcome to Orbit.

—

Terms of Use (EULA): https://orbitbrain2.netlify.app/terms
Privacy Policy: https://orbitbrain2.netlify.app/privacy

By downloading Orbit, you agree to the Terms of Use linked above. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period — manage or cancel anytime from iOS Settings → Apple ID → Subscriptions.
```

> Rationale: first three lines (~250 chars) are what the App Store
> shows before the "more" tap, so the hook + USP + permission-to-be-lazy
> all happen up top. The sections use the App Store's accepted
> em-dash-header pattern (`— HEADER —`) which Apple renders cleanly.
>
> **The closing Terms of Use / Privacy Policy block is required by
> Apple Guideline 3.1.2(a)** for any app with auto-renewable
> subscriptions. The Terms of Use URL must be a functional link
> visible in the description body text — putting it only in the
> App Information → Privacy Policy URL field is not enough. Apple's
> review bot scans the description text for this and auto-rejects
> if missing.

---

## What's New (4000 char max — for version 1.0)

```
Welcome to Orbit.

This is our first release — a calm second brain built around Apple Intelligence and designed to feel native, fast, and quiet.

Everything works on-device first. Your memories stay yours.
```

> Rationale: short and inviting. For point releases later, switch to
> a bulleted "Added / Improved / Fixed" pattern.

---

## Categories

- **Primary**: Productivity
- **Secondary**: Lifestyle

> Rationale: Productivity is where second-brain / journal / note apps
> live and rank. Lifestyle as secondary captures the wellness +
> gratitude crowd.

---

## Age Rating

**4+** (no objectionable content)

---

## URLs

| Field             | Value                                          |
|-------------------|------------------------------------------------|
| Marketing URL     | https://orbitbrain2.netlify.app                |
| Support URL       | https://orbitbrain2.netlify.app/support        |
| Privacy Policy    | https://orbitbrain2.netlify.app/privacy        |

---

## Privacy Nutrition Labels (App Privacy section)

You'll fill this out via a guided questionnaire in App Store Connect.
Below is the truthful answer set for Orbit as it ships today.

### Data Linked to You

Required because the user signs in with Apple, which provides a stable
identifier.

- **Identifiers**: User ID (Apple's sub identifier from Sign in with Apple)
- **Contact Info**: Name, Email Address (only if the user chooses to share
  during Apple Sign-In; both can be hidden)

**Used for**: App Functionality (sign-in).
**Tracking**: No.

### Data Not Collected by Us

All other data lives on-device and/or in the user's private iCloud:

- Memories (text, voice, photos, links, locations)
- HealthKit data (sleep + steps — read for Daily Recap, not stored elsewhere)
- Calendar / Reminders content (read/write for sync feature, not stored elsewhere)

> Note: iCloud sync is *user-owned*. Apple holds the encrypted data on
> the user's behalf; Orbit (the company) never sees it. This is
> standard CloudKit and doesn't count as data collection for the
> Privacy Nutrition Label.

### Tracking

**Orbit does not track users** across other apps or websites owned by
other companies. Set IDFA / tracking permission to **off**.
