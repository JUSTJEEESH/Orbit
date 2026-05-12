# Voice memo scripts for screenshots

Three of the seed memories in `../seed-data.md` are voice notes.
Recording them yourself works fine, but using macOS's built-in `say`
command gives you cleaner, take-after-take consistency without
audible "uhms."

The scripts:

| File                       | Used by | Length |
|----------------------------|---------|--------|
| `01-bookshop.txt`          | Memory #1 — anchors the Ask Orbit demo  | ~40s |
| `05-restaurant.txt`        | Memory #5 — answers the Ask Orbit query | ~45s |
| `08-running.txt`           | Memory #8 — feeds the Habits tab        | ~35s |

---

## How it works

1. iOS Simulator's microphone uses the Mac's microphone.
2. `say` plays text through the Mac's speakers.
3. While the simulator is recording a voice note, the Mac's mic
   picks up the speaker output — clean, identical every time.

No external software, no virtual audio routing, no setup.

---

## One-time check: pick a voice you like

macOS ships with a few default voices, plus lots of free higher-
quality "Premium" / "Personal" voices you can download.

List the voices currently installed:

```bash
say -v '?'
```

Recommended choices (Samantha works on a stock Mac without
downloads; Ava is higher quality but you may need to download it):

| Voice    | Where to find                    | Notes                                |
|----------|----------------------------------|--------------------------------------|
| Samantha | Default on every Mac             | The classic Siri voice. Always works.|
| Ava      | System Settings → Accessibility → Spoken Content → System Voice → Manage Voices → English (US) → "Ava (Premium)" | Higher fidelity, more natural cadence. ~150MB download. |

For v1 screenshots, Samantha is fine.

---

## The workflow

### Step 1 — boot the simulator and open Orbit

Make sure the simulator is running and Orbit is open. Mac volume up
to ~70%. Don't be in a noisy room.

### Step 2 — start the voice capture

In Orbit:

1. Tap the FAB (+) → Capture sheet opens
2. Tap the **Voice** mode in the segmented control at the top
3. Tap **Start recording**

The waveform begins moving. Now you have a few seconds before
needing to start playback.

### Step 3 — play the script through speakers

From a Terminal window in this folder, run **one** of:

```bash
# Memory 1 — the bookshop note (anchors Ask Orbit demo)
say -v Samantha -r 175 -f 01-bookshop.txt

# Memory 5 — the restaurant note (answers the Ask Orbit query)
say -v Samantha -r 175 -f 05-restaurant.txt

# Memory 8 — the running note (feeds Habits tab)
say -v Samantha -r 175 -f 08-running.txt
```

Flags:

- `-v Samantha` — which voice to use (swap for `Ava` if you've
  downloaded it).
- `-r 175` — words per minute. Default is 200 (sounds rushed);
  175 reads as a calm, natural conversational pace.
- `-f filename.txt` — read the script from a file. Cleaner than
  pasting the text inline (no quote escaping).

`say` blocks until it finishes speaking, so the terminal is locked
while it reads. That's a feature: when control returns to the
prompt, you know it's done.

### Step 4 — stop recording in Orbit

Once `say` has finished and control returns to your terminal prompt,
switch back to the simulator and tap **Stop**. Orbit transcribes
the audio on-device. Tap **Save**.

### Step 5 — verify the transcript

Open the new memory in the Timeline. The transcript should be a
near-perfect copy of the script. If it dropped a sentence (rare with
`say`), you can re-record — voice notes are easy to redo.

---

## Tips

- **Skip Ava for now.** Samantha is good enough and saves you the
  download. Switch to Ava only if you do another round of
  screenshots and want to A/B test fidelity.
- **Mute notifications** in Mac System Settings before recording.
  A surprise calendar ding will end up transcribed into your memo.
- **Don't talk over `say`.** The mic will pick up both. Hands off
  the keyboard.
- **External speakers help a little.** Built-in MacBook speakers
  are fine, but a small Bluetooth speaker placed near the Mac mic
  gives a noticeable clarity bump. Optional for v1.
- **If a transcript is wrong**, the easy fix is to re-record. The
  in-app voice editor is for trimming, not for rewriting transcript
  text directly.

---

## Why not just type the transcripts into a text memory?

You could — and the timeline would still show body content. But the
**voice-memo UI is visually distinct**: a waveform graphic, a
"Voice · 2:47 PM" eyebrow, an audio playback control. Without an
actual voice memo in the seed, the Memory Detail screenshot (#3)
and the timeline kind-mix lose visual variety.

Two of these scripts (#1 and #5) also feed the **Ask Orbit demo**.
That demo asks the AI to retrieve from your captures by content. As
long as the body text is right (whether captured as voice or text),
the answer will land — but for the most authentic screenshot, the
source should look like a voice note.
