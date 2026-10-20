# Phase 0 — App Store Growth Playbook

**Goal:** more people find Orbit, and more of the people who find it download it.
**Scope:** App Store Connect, the website, and outreach. **No app code changes.**
**Owner:** you. Every step below says *where* to do it and *exactly what to type*.

> The only engineering task in Phase 0 is re-uploading the **same code** with a
> bumped version number (Step 2). Apple only lets you change the name, subtitle,
> keywords, description and screenshots when you submit a new version. The app
> your users run is unchanged.

---

## 0. Baseline and targets

Snapshot taken Oct 20, 2026 from App Store Connect and RevenueCat.

| Metric | Today | 6-week target | Where to read it |
|---|---|---|---|
| Impressions | 5.85K | keep or grow | App Analytics → Metrics → Impressions |
| Product page views | 462 | 700+ | App Analytics → Metrics → Product Page Views |
| Page view → download | **12.6%** (58 / 462) | **20%+** | Downloads ÷ Product Page Views |
| Search page views | **129** | **250+** | Product Page Views, *View by: Source Type* |
| Search conversion | 22% | keep ≥ 22% | Total Downloads ÷ Page Views, Source = Search |
| Browse conversion | **6.7%** | **12%+** | same, Source = Browse |
| Web referrer conversion | **4.5%** | **15%+** | same, Source = Web Referrer |
| Ratings | **1** | **15+** | App Store → Ratings and Reviews |
| Yearly trials converted | 0 of 3 | (Phase 1) | RevenueCat → Customers |

**Save these numbers.** Every week, add a row to the tracker in section 12.

### What the numbers told us

1. **Search and social links convert 3× better than everything else**, but
   search sends only ~1–2 visitors a day. Better keywords = more of the best
   traffic.
2. **Impressions doubled while conversion fell 64%.** Today's keywords
   (`mood, habit, tracker, gratitude, wellness, mindful…`) put Orbit in front of
   people looking for mood trackers and habit trackers. They see Orbit, it isn't
   what they wanted, they scroll on. We stop competing for searches we can't win.
3. **Browse visitors leave** (6.7%). They decide from the icon and the first 3
   screenshots in about two seconds. Today's slide 1 is text-only
   ("Memory shouldn't fail you.") — it doesn't show the product or say what it
   does.
4. **Website visitors almost never install** (3 of 66). Most are probably on a
   computer, where they can't install an iPhone app.
5. **1 rating** means no visible stars in search results and a weak ranking
   signal.
6. **Almost every buyer is outside the US** (Spain, Brazil, Denmark, Norway,
   Ireland). Orbit has no listing in Spanish or Portuguese.

---

## 1. Decision: positioning (pick one)

Three complete options. Each is **name + subtitle + keyword field** together,
because Apple combines words across all three and **counts every word only once**
— repeating a word between fields wastes space.

All character counts are checked (limit: name 30, subtitle 30, keywords 100).

### ✅ Option A — "Brain dump & memory" (recommended)

| Field | Text | Length |
|---|---|---|
| Name | `Orbit: AI Brain Dump & Memory` | 29 |
| Subtitle | `Voice notes for ADHD minds` | 26 |
| Keywords | `second,remember,forgetful,memo,transcribe,idea,thought,journal,diary,recall,reminder,organize,text` | 98 |

**Why this one:**
- Says what Orbit *does* in plain words, in the place that shows up in search
  results.
- Gives one clear audience (the PRD's #1 user) without excluding anyone else.
- **Keeps the searches that already work.** `ai` + `brain` (name) + `second`
  (keywords) still matches "AI second brain". `journal` stays.
- Adds less crowded, high-intent searches: *brain dump*, *voice memo*,
  *transcribe*, *forgetful*, *remember*, *recall*, *idea*.
- Combinations Apple builds automatically from these words include:
  "adhd brain dump", "brain dump app", "voice notes", "voice memo",
  "ai voice notes", "memory app", "second brain", "idea journal",
  "voice to text notes", "remember things", "voice journal", "ai journal".

**Trade-off:** "ADHD brain dump" has many new apps since late 2025 (BrainDump,
Jot, BrainSort, Recordo, dump…). Most of them are **task planners** with few
ratings. Orbit's angle — *memory*: it remembers and finds things for you — is
different, and that difference is what the subtitle, screenshots and description
lead with.

### Option B — "Remember everything" (broader, softer)

| Field | Text | Length |
|---|---|---|
| Name | `Orbit — Remember Everything` | 27 |
| Subtitle | `AI brain dump & voice notes` | 27 |
| Keywords | `adhd,second,memory,forgetful,memo,transcribe,idea,thought,journal,diary,recall,reminder,text,capture` | 100 |

Choose this if you'd rather not lead with ADHD on the visible page.
"Remember everything" is emotional, but it's a lower-volume search phrase than
"brain dump".

### Option C — Conservative (keep the current name)

| Field | Text | Length |
|---|---|---|
| Name | `Orbit — AI Second Brain` *(unchanged)* | 23 |
| Subtitle | `ADHD brain dump & voice notes` | 29 |
| Keywords | `memory,remember,forgetful,memo,transcribe,idea,thought,journal,diary,recall,reminder,organize,text` | 98 |

Lowest risk if you're attached to the name. It still fixes the biggest problem
(the mood/habit/tracker keywords).

### Words we are deliberately removing (all options)

| Removed | Why |
|---|---|
| `mood`, `habit`, `tracker` | Searchers want Daylio/Streaks-style trackers. Likely cause of the conversion drop. |
| `gratitude`, `wellness`, `mindful`, `reflect` | Searchers want meditation/wellness apps (Calm, Headspace, Five Minute Journal). |
| `lifelog`, `captures`, `daily`, `thoughts` | Very low volume, or replaced by a better word (`thought`). |

**Rules for the keyword field** (so you don't accidentally waste characters):
- Commas only, **no spaces** after commas.
- Singular form (`idea`, not `ideas`). Apple matches most plurals.
- Never repeat a word that's in the name or subtitle.
- Never include "Orbit", "app", "iPhone", competitor names (Notion, Day One,
  Apple Journal) or category names. Competitor names break App Review guideline
  2.3.7 and can get the update rejected.

### Optional: check search popularity before deciding (~20 minutes, free)

You can't see Apple's search volume directly, but Apple Ads shows a popularity
score.

1. Go to **ads.apple.com** → sign in with your developer Apple ID → choose
   **Apple Ads Advanced** (not Basic).
2. **Create Campaign** → app *Orbit* → **Search Results** → any country (US) →
   any budget. **You don't have to launch it.**
3. Create an ad group → **Add Keywords**. Type each candidate: `brain dump`,
   `adhd brain dump`, `voice notes`, `voice memo`, `second brain`,
   `ai journal`, `memory app`, `remember`, `forgetful`, `mood tracker` (for
   comparison).
4. Each keyword shows **Search Popularity** bars (1–5). The suggestion list
   also shows related searches you might add.
5. Leave the campaign **paused/unsaved** if you don't want to spend money.

If `brain dump` or `adhd brain dump` shows 1 bar while `voice notes` shows 3+,
go with Option B.

---

## 2. Promotional text (no review, change any time)

This sits above the description. It isn't searchable, but it's what people read
first on the page. **It updates instantly, without submitting a new version.**
You can change it today.

**English (U.S.) and English (U.K.)** — 158 characters (limit 170)
```
Brain dump anything — a thought, a voice note, the link you saved at 2am. Orbit sorts it quietly and finds it again the moment you ask. Private and on-device.
```

**Spanish (Mexico) and Spanish (Spain)** — 147
```
Vacía tu mente: una idea, una nota de voz, el enlace de las 2 a. m. Orbit lo ordena solo y te lo encuentra cuando lo pidas. Privado y en tu iPhone.
```

**Portuguese (Brazil)** — 152
```
Esvazie a mente: uma ideia, uma nota de voz, o link das 2 da manhã. O Orbit organiza tudo sozinho e encontra quando você pedir. Privado e no seu iPhone.
```

Use promotional text for timely messages later: "Year in Review is here",
launch offers, and so on.

---

## 3. Description

The description **doesn't affect search ranking** on iOS, but the first ~3 lines
show before "more" and help visitors decide. Replace **only the opening**. Keep
the rest of the current description, including the required Terms/Privacy block
at the end (guideline 3.1.2).

### English (U.S. and U.K.) — replace the first two paragraphs with:

```
Brain dump anything — a thought, a voice note, a screenshot, the link you saved at 2am. Orbit organizes it for you and finds it again the moment you ask.

Built for busy, forgetful and ADHD minds. No folders. No tagging. No setup. Just get it out of your head.
```

Then continue with the existing `— WHAT YOU GET —` section unchanged.

### Spanish (Mexico and Spain) — full description

```
Vacía tu mente en segundos: una idea, una nota de voz, una captura de pantalla, el enlace que guardaste a las 2 a. m. Orbit lo organiza por ti y lo encuentra en cuanto se lo pides.

Hecho para mentes ocupadas, olvidadizas y con TDAH. Sin carpetas. Sin etiquetas. Sin configurar nada.

— LO QUE OBTIENES —

• Guarda cualquier cosa en segundos: texto, notas de voz, fotos, enlaces, capturas de pantalla o un lugar. Apple Intelligence se encarga del resto: títulos, etiquetas, resúmenes y categorías.

• Pregúntale a Orbit: conversa con tus propios recuerdos. «¿Qué restaurante me recomendaron en Roatán?» Orbit responde a partir de lo que guardaste.

• Resumen diario: cada noche, un párrafo que recoge lo que valió la pena de tu día.

• Tareas que aparecen solas: escribe «tengo que llamar a mamá mañana» y Orbit te lo sugiere como tarea.

• Hace un año, Tu año en Orbit y Cápsulas del tiempo: tu pasado vuelve en el momento justo.

• Privado por diseño: IA en el dispositivo con Apple Intelligence. La voz se transcribe en tu iPhone. Sincronización con tu iCloud. Nada se vende. Nada se comparte.

— HECHO PARA APPLE —

Captura desde la pantalla bloqueada · Notas de voz en Apple Watch · Atajos de Siri · Búsqueda en Spotlight · Widgets · Extensión de Safari · Sincronización con Recordatorios y Calendario

— IDIOMA —

La interfaz de la app está en inglés. Puedes escribir y dictar tus notas en español: la transcripción de voz usa el idioma de tu iPhone.

— PRO —

Una suscripción mensual o anual, o un pago único de por vida, desbloquea capturas ilimitadas y todas las funciones de IA. Cancela cuando quieras.

—

Términos de uso (EULA): https://orbitbrain2.netlify.app/terms
Política de privacidad: https://orbitbrain2.netlify.app/privacy

Las suscripciones se renuevan automáticamente salvo que se cancelen al menos 24 horas antes del final del periodo actual. Adminístralas en Ajustes de iOS → Apple ID → Suscripciones.
```

### Portuguese (Brazil) — full description

```
Esvazie a mente em segundos: uma ideia, uma nota de voz, um print, o link que você salvou às 2 da manhã. O Orbit organiza tudo para você e encontra assim que você pedir.

Feito para mentes ocupadas, esquecidas e com TDAH. Sem pastas. Sem etiquetas. Sem configurar nada.

— O QUE VOCÊ GANHA —

• Salve qualquer coisa em segundos: texto, notas de voz, fotos, links, prints ou um lugar. O Apple Intelligence cuida do resto: títulos, etiquetas, resumos e categorias.

• Pergunte ao Orbit: converse com as suas próprias memórias. "Qual era o restaurante que me indicaram em Roatán?" O Orbit responde a partir do que você salvou.

• Resumo diário: toda noite, um parágrafo com o que valeu a pena no seu dia.

• Tarefas que aparecem sozinhas: escreva "preciso ligar para a minha mãe amanhã" e o Orbit sugere como tarefa.

• Neste dia, Seu ano no Orbit e Cápsulas do tempo: o seu passado volta na hora certa.

• Privacidade desde o início: IA no dispositivo com Apple Intelligence. A voz é transcrita no seu iPhone. Sincronização pelo seu iCloud. Nada é vendido. Nada é compartilhado.

— FEITO PARA A APPLE —

Captura pela Tela Bloqueada · Notas de voz no Apple Watch · Atalhos da Siri · Busca no Spotlight · Widgets · Extensão do Safari · Sincronização com Lembretes e Calendário

— IDIOMA —

A interface do app está em inglês. Você pode escrever e ditar as suas notas em português: a transcrição de voz usa o idioma do seu iPhone.

— PRO —

Uma assinatura mensal ou anual, ou um pagamento único vitalício, libera capturas ilimitadas e todos os recursos de IA. Cancele quando quiser.

—

Termos de uso (EULA): https://orbitbrain2.netlify.app/terms
Política de privacidade: https://orbitbrain2.netlify.app/privacy

As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período atual. Gerencie em Ajustes do iOS → Apple ID → Assinaturas.
```

> **Why the "Idioma" section matters:** the app interface is English-only. Without
> this line, Spanish and Portuguese buyers would expect a translated app and
> leave 1-star reviews. Voice transcription follows the iPhone's language
> (`SpeechTranscriber` uses `Locale.current`), so dictating in Spanish or
> Portuguese genuinely works.

> **Get a native speaker to proofread** the Spanish and Portuguese text before
> you submit. A friend, or a Fiverr/Upwork proofreader for about $20–40, is
> enough. My translations are solid, but a native eye catches tone.

---

## 4. Localized names, subtitles and keywords

Add these **localizations** to your listing. Each one gets its own name,
subtitle, keywords, description and (optionally) screenshots.

| Localization | Why |
|---|---|
| **English (U.K.)** | Used by the UK and Ireland storefronts (and you had an Irish trial). An extra, separate keyword set. |
| **Spanish (Mexico)** | Mexico and Latin America. **The US App Store also indexes Spanish (Mexico) keywords**, so this adds Spanish-language searches in the US too. |
| **Spanish (Spain)** | Spain (you have a paying subscriber there). |
| **Portuguese (Brazil)** | Brazil (your lifetime purchase came from there). Big market, far less competitive in Portuguese. |

### English (U.K.)
Copy Option A exactly. Change only `organize` → `organise` in keywords.

### Spanish (Mexico)
| Field | Text | Length |
|---|---|---|
| Name | `Orbit: Notas de Voz y Memoria` | 29 |
| Subtitle | `Descarga mental para TDAH` | 25 |
| Keywords | `ia,segundo,cerebro,recordar,olvido,ideas,diario,apuntes,transcribir,grabadora,recordatorio,tareas` | 97 |

### Spanish (Spain)
| Field | Text | Length |
|---|---|---|
| Name | `Orbit: Notas de Voz y Memoria` | 29 |
| Subtitle | `Vacía tu mente, sin olvidar` | 27 |
| Keywords | `ia,tdah,segundo,cerebro,recordar,olvido,ideas,diario,apuntes,transcribir,grabadora,recordatorio` | 95 |

### Portuguese (Brazil)
| Field | Text | Length |
|---|---|---|
| Name | `Orbit: Notas de Voz e Memória` | 29 |
| Subtitle | `Esvazie a mente, sem esquecer` | 29 |
| Keywords | `ia,tdah,segundo,cérebro,lembrar,ideias,diário,anotações,transcrever,gravador,lembrete,tarefas` | 97 bytes |

> Accented letters (é, ç, ã) count as 2 bytes in the keyword field. If App Store
> Connect says the field is too long, drop `tarefas`.

---

## 5. Screenshots

### What changes

Only the **first 3 slots** change meaning. They're the only ones most people
see, and they're what search results show. Slots 4–9 reuse the existing assets
from `screenshots.md`, re-ordered, with the weakest slide removed.

**Rules for slots 1–3:**
- Headline **4 words or fewer**. In search results the screenshots appear at
  about ¼ size, so long headlines become unreadable.
- **Every slot shows the real app UI.** No text-only slides at the front.
- One idea per slide: *capture → it's organized → you can find it.* That's the
  whole product in three frames.

### New order

| Slot | Headline | Subline | App state to capture | Was |
|---|---|---|---|---|
| **1** | `Brain dump anything.` | `Talk, type, snap or share — saved in 2 seconds.` | Capture sheet in **Voice** mode, recording in progress: waveform visible, timer ~0:08, the mode switcher (Text / Voice / Photo / Link) visible. | *new* (replaces text-only "Memory shouldn't fail you.") |
| **2** | `Orbit sorts it.` | `Titles, tags and to-dos — no folders.` | Memory Detail of the seeded **bookshop voice note**: AI title, summary card, 2–3 tag chips, and a suggested-task chip if visible. | old #3 ("It organizes itself.") |
| **3** | `Just ask.` | `"What was the restaurant Pamela mentioned?"` | Ask Orbit with the Pamela answer and its source memory chip. | old #5 |
| 4 | `A day, read back.` | *(unchanged)* | Daily Recap | old #4 |
| 5 | `Tasks find themselves.` | *(unchanged)* | Tasks tab with suggestions | old #7 |
| 6 | `Your past, on cue.` | *(unchanged)* | Year in Review | old #6 |
| 7 | `Nothing leaves your phone.` | *(unchanged)* | Privacy back cover | old #10 — moved up; trust matters for a personal memory app |
| 8 | `Wherever you are.` | *(unchanged)* | Ecosystem composition | old #8 |
| 9 | `Worth sharing.` | *(unchanged)* | Share card | old #9 |

Old #2 ("One place. Everything saved.") is absorbed into the new slot 1.

**Backgrounds:** make slot 1 **dark `#0E0E0E`** with the device frame. It
stands out next to the white/grey screenshots of other apps in search results,
and keeps the brand's editorial cover feel. Slots 2–3 stay off-white
`#FBFAF7`. Typography, padding and device frame follow `screenshots.md`.

### Localized captions (slots 1–3)

The app UI in the screenshot stays English; only the headline/subline change.
If you skip this, Spanish and Portuguese pages fall back to the English
screenshots. That's acceptable, but localized captions convert noticeably
better.

| Slot | Spanish (MX + ES) | Portuguese (BR) |
|---|---|---|
| 1 | `Vacía tu mente.` / `Habla, escribe, fotografía o comparte. Listo en 2 segundos.` | `Esvazie a mente.` / `Fale, digite, fotografe ou compartilhe. Pronto em 2 segundos.` |
| 2 | `Orbit lo ordena.` / `Títulos, etiquetas y tareas, sin carpetas.` | `O Orbit organiza.` / `Títulos, etiquetas e tarefas, sem pastas.` |
| 3 | `Solo pregunta.` / `Orbit responde con tus propios recuerdos.` | `É só perguntar.` / `O Orbit responde com as suas memórias.` |

### How to produce them (same workflow you used for v3)

1. Run the app in the **iPhone 16 Pro Max** (or 17 Pro Max) simulator.
2. Settings → Developer → **Seed demo memories** (see `seed-data.md`).
3. Capture the three app states above with **⌘S** in the simulator.
4. In ButterKit (or Figma), duplicate your existing v3 template. Replace the
   slot 1–3 captions and screens, and re-order 4–9 as listed.
5. Export at **1290 × 2796** PNG. Duplicate the set for each language and swap
   the captions.
6. Name files `01-…png` to `09-…png` so they upload in the right order.

---

## 6. Step-by-step: shipping the new listing

**Total time:** about 3–4 hours of your work, plus 1–2 days for Apple review.

### Step 1 — Promotional text (today, 5 min, no review)

1. **appstoreconnect.apple.com** → **Apps** → **Orbit**.
2. **Distribution** tab → left sidebar → under **iOS App**, click your
   **live version** (e.g. *1.0.1 Ready for Distribution*).
3. Language menu (top right of the version page) → **English (U.S.)**.
4. **Promotional Text** → paste the English text from section 2 → **Save**.
   It's live within about an hour, with no review.

### Step 2 — Upload the same build with a new version number (30 min)

Apple won't let you change name, subtitle, keywords, description or screenshots
on a live version. You need a new version, so you need a new build — of the
exact same code.

1. On your Mac, in the repo: `git checkout main && git pull`.
2. Open `project.yml`. Set:
   ```yaml
   MARKETING_VERSION: "1.0.2"
   CURRENT_PROJECT_VERSION: "1"
   ```
   (If the live version isn't 1.0.1, use the next number after it.)
3. Terminal: `xcodegen generate`, then `open Orbit.xcodeproj`.
4. Xcode → scheme **Orbit** → destination **Any iOS Device (arm64)** →
   **Product → Archive**.
5. Organizer → **Distribute App** → **App Store Connect** → **Upload**. Keep
   the defaults.
6. Wait for the "processing complete" email from Apple (10–30 minutes).
7. Commit the version bump (`git commit -am "Bump to 1.0.2 for listing refresh"`)
   and push.

> **No code changes** go into this build. Same app, new number. That's what
> keeps Phase 0 zero-risk for current users.

### Step 3 — Create version 1.0.2 in App Store Connect (5 min)

1. **Distribution** tab → sidebar → click the **+** next to **iOS App** →
   type `1.0.2` → **Create**.
2. App Store Connect copies all current metadata and screenshots into the new
   version. You'll only edit what changes.
3. Scroll to **Build** → **+** → choose the 1.0.2 (1) build you uploaded →
   **Done**. Answer the export-compliance question the same way you did for
   1.0.1.

### Step 4 — Name and subtitle (App Information, 15 min)

1. Sidebar → **App Information** (under *General*).
2. Language menu (top right) → **English (U.S.)**.
3. **Name** → `Orbit: AI Brain Dump & Memory` (or your chosen option).
4. **Subtitle** → `Voice notes for ADHD minds`.
5. **Save**.

**Add the new localizations here:**

6. Language menu → **Add Language** (bottom of the list) → **English (U.K.)**.
   Enter the name and subtitle → **Save**.
7. Repeat for **Spanish (Mexico)**, **Spanish (Spain)** and
   **Portuguese (Brazil)** with the names and subtitles from section 4.
8. Each new localization also needs a **Privacy Policy URL**:
   `https://orbitbrain2.netlify.app/privacy`.

> Primary language and categories stay as they are (English (U.S.),
> Productivity / Lifestyle).

### Step 5 — Version page, English (U.S.) (20 min)

Sidebar → **1.0.2 Prepare for Submission** → language **English (U.S.)**:

1. **Promotional Text** → already updated in Step 1.
2. **Description** → replace the first two paragraphs (section 3). Make sure
   the Terms/Privacy block is still at the bottom.
3. **Keywords** → paste the keyword line for your option. Check the counter
   shows ≤ 100.
4. **What's New in This Version** →
   ```
   A refreshed App Store page. No changes to your memories, settings or subscription.
   ```
   (Honest, and reassures existing users that nothing moved.)
5. **iPhone 6.9" Display screenshots** → hover over the existing set → delete
   them → drag in the new `01…09` set. Drag to re-order if needed.
6. **Save**.

### Step 6 — Version page, the 4 new localizations (40 min)

For **each** of English (U.K.), Spanish (Mexico), Spanish (Spain) and
Portuguese (Brazil), switch the language menu, then fill in:

- **Promotional Text** (section 2)
- **Description** (section 3: English for U.K., the full translated versions
  for the others)
- **Keywords** (section 4)
- **Support URL** `https://orbitbrain2.netlify.app/support`
- **Marketing URL** `https://orbitbrain2.netlify.app`
- **What's New** (English for U.K. as in Step 5. Spanish:
  `Nueva página en la App Store. Tus recuerdos, ajustes y suscripción no cambian.`
  Portuguese: `Nova página na App Store. Suas memórias, ajustes e assinatura não mudam.`)
- **Screenshots** — upload the localized set, or leave empty to fall back to
  English.
- **Save**.

### Step 7 — Submit (5 min)

1. Top of the 1.0.2 page → **Add for Review** → **Submit to App Review**.
2. **Version release:** choose **Automatically release this version**.
   Phased release doesn't matter here, since the code is identical.
3. Notes for App Review (optional):
   ```
   Metadata refresh only (name, subtitle, keywords, screenshots, new localizations). The binary is functionally identical to 1.0.1. The app UI is English; localized listings state this in the description.
   ```
4. Typical review time is 24–48 hours.

### Step 8 — Right after approval: watch, don't touch (days 1–7)

- Search ranking reshuffles for **24–72 hours** after a keyword change. A dip
  on day 1–2 is normal.
- Check on your iPhone, in a private Safari tab or logged-out App Store, that
  searching `brain dump`, `adhd brain dump`, `voice notes ai` and
  `second brain` shows Orbit. Note the position (row 1, 5, 20…) in the tracker.
- **Don't change anything for 14 days.** Changing the listing again too soon
  makes the results impossible to read.

---

## 7. Custom Product Pages (after 1.0.2 is approved)

A Custom Product Page (CPP) is an alternate version of your App Store page with
its own screenshots and promotional text, and its own link. Since mid-2025,
**you can assign keywords to a CPP** so it appears in search for those terms
instead of your default page. You can have up to 70.

**Rules that matter:**
- Keywords you assign must come from the keyword field of your **latest
  approved version**. That's why this happens after 1.0.2 is live.
- **Each keyword can belong to only one page.**
- CPPs are reviewed separately from app updates. No new build is needed.
- You can't change the name, subtitle or icon on a CPP. You *can* change
  screenshots, preview video and promotional text, per localization.

### The 4 pages to create

| # | Reference name | Assigned keywords | Screenshot slot 1 headline | Promotional text |
|---|---|---|---|---|
| 1 | `Voice notes` | `memo`, `transcribe`, `text` | `Talk. It's saved.` | `Hold to talk, let go to save. Orbit transcribes on your iPhone and files it for you — find any voice note by asking.` |
| 2 | `Forgetful` | `remember`, `forgetful`, `recall`, `reminder` | `Never lose a thought.` | `For the things you swear you'll remember. Orbit keeps them, sorts them, and brings them back when you need them.` |
| 3 | `Journal` | `journal`, `diary`, `thought` | `A journal that writes back.` | `Capture moments in seconds. Every evening Orbit reads your day back to you — gently, never demanded.` |
| 4 | `Social` | *(none)* | same as the default page | `You saw it on social — here it is. Brain dump anything; Orbit remembers it for you.` |

Page 4 is for every link you post on TikTok, Instagram, Reddit, the website
and so on. That way you can see exactly how much traffic and how many downloads
your own posts drive (App Analytics → filter by **Product Page**).

For pages 1–3, only slot 1's headline and screen change (put voice capture,
recall, or Daily Recap first). The rest of the set can be the default
screenshots.

### Where and how

1. **Distribution** tab → sidebar → **Custom Product Pages** (under *Features*
   or *Growth & Marketing*, depending on your App Store Connect layout) →
   **Create Custom Product Page**.
2. **Reference name** (internal only) → e.g. `Voice notes`. Start from
   **a copy of the default product page**.
3. Upload the screenshots → set promotional text for each localization.
4. **Keywords** section → assign the keywords from the table above.
5. **Deep link:** leave empty for now. It needs app work and comes in Phase 1.
6. **Add for Review** → **Submit**.
7. Once approved, set it to **Visible**. Copy its **URL**. It looks like
   `https://apps.apple.com/app/id6769115384?ppid=…`. Store all 4 URLs in the
   tracker.

---

## 8. Icon test with Product Page Optimization (after 1.0.2 is live)

The three alternate icons (**Sunset**, **Cosmic**, **Forest**) are **already
inside your published app**
(`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.yml`). That means
you can A/B-test them on the App Store **without a new build**.

**Be realistic about traffic.** About 65 impressions a day is low. A test needs
roughly 4–8 weeks to reach Apple's 90% confidence, so test **one** thing with a
big split.

1. **Distribution** tab → sidebar → **Product Page Optimization** →
   **Create Test**.
2. Name: `Icon test 1`. **Traffic proportion: 50%**. **Treatments: 1** (more
   treatments split the traffic too thinly).
3. Treatment A → **App Icon** → pick the alternate icon with the strongest
   contrast against white. Look at your icon set and pick the boldest one,
   likely Cosmic or Sunset.
4. Localizations: all.
5. **Submit for Review** → once approved, **Start Test**.
6. Read results under **App Analytics → Product Page Optimization**. Only act
   when a treatment shows **"Performing better" at 90%+ confidence**. If it
   wins, **Apply Treatment**, and in Phase 1 we make that icon the default in
   the binary.

> Notes: you can run only one test at a time, and you can't edit a test after
> it starts. People in the test who already have Orbit installed see the test
> icon on their home screen too. Harmless, but don't be surprised if a user
> mentions it.

**Why not A/B-test the screenshots instead?** At your traffic, a screenshot
test would take months to be conclusive. The current first slide is clearly
weak, so it's better to ship the improved set directly (Step 5) and compare
before vs after in the tracker.

---

## 9. Website fixes (Netlify, `docs/marketing/website/`)

Website visitors convert at 4.5% because most of them are on a computer. Four
fixes, each a small HTML/config edit (say the word and I'll make them).

### 9a. Smart App Banner (iPhone visitors)

In `index.html`, inside `<head>`, add:
```html
<meta name="apple-itunes-app" content="app-id=6769115384">
```
iPhone Safari visitors then get Apple's native "Open / Get" banner at the top
of the page.

### 9b. QR code for desktop visitors

Next to the hero "Download for iPhone" button, add a QR code (≈120 px) with the
caption "Scan with your iPhone camera". Point it at the **Social** Custom
Product Page URL from section 7. Generate it with any QR tool, or I can generate
an SVG.

### 9c. Short links for posts and bios

In `netlify.toml` add:
```toml
[[redirects]]
  from = "/get"
  to = "https://apps.apple.com/app/id6769115384?ppid=<SOCIAL_PPID>"
  status = 302
```
Then use **orbitbrain2.netlify.app/get** in every bio and post: short, easy
to remember, and it lands on the trackable page.

### 9d. Match the new positioning

Update the `<title>`, `<meta name="description">` and `og:` tags to use the new
name and the "brain dump / remember" promise, so link previews in iMessage and
social media match the App Store.

---

## 10. Ratings (from 1 to 15+ in 6 weeks)

The in-app prompt fix is Phase 1. Until then, ask people directly. **Never offer
anything in return** — incentivized reviews break Apple's rules (guideline
5.6, Developer Code of Conduct) and can get the app removed.

**Direct review link** (opens the "Write a Review" sheet):
```
https://apps.apple.com/app/id6769115384?action=write-review
```

**Who to ask:** people you know who've genuinely used Orbit for at least a few
days, your social followers, and any beta testers.

**Message template (DM / iMessage / email):**
```
Hey! I built Orbit — the brain-dump/memory app you've been trying. If it's been useful, an honest App Store rating would help a lot; it's a tiny indie app and ratings decide whether anyone finds it. Takes 10 seconds: https://apps.apple.com/app/id6769115384?action=write-review — and if something annoyed you, tell me instead, I'll fix it.
```

**In social posts:** one line at the end of every ~3rd post: "Using Orbit?
A rating helps more than you'd think → link".

**Reply to every review** from App Store Connect → **Ratings and Reviews**.
Replies are public and show future visitors that someone cares.

---

## 11. Social posting (your best-converting channel)

App Referrer traffic converts at **24%**, the best of any source. Your spikes
(Aug 9–10, Sep 17, Sep 23, Oct 7) look like post days. Whatever you did then,
do it on a schedule.

**Cadence:** 3 short videos a week (TikTok + Instagram Reels + YouTube Shorts,
the same clip on all three), plus 1 longer text post a week (Reddit/X/Threads).

**Five video formats that suit Orbit** (15–30 s, screen recording + voiceover,
vertical):
1. **"2am thought"** — dark room, phone, hold to talk → "remind me to email Sam
   about the invoice" → next morning it's a task. Caption: *my ADHD brain at 2am
   vs. Orbit*.
2. **"Where did I see that?"** — screenshot a restaurant on Instagram → share
   to Orbit → days later, Ask Orbit "what was that ramen place?" → found.
3. **"Daily Recap"** — evening, open the recap, read the paragraph aloud. Calm,
   aesthetic.
4. **"Before / after"** — a chaotic Notes app / camera roll of screenshots →
   one calm Orbit timeline.
5. **"Build in public"** — "I'm an indie dev, here's what I shipped this week"
   with real numbers. Indie-dev audiences share these.

You already have voice scripts in `docs/marketing/voice-scripts/` to reuse.

**Every post links to `orbitbrain2.netlify.app/get`** (→ Social CPP), so you
can measure it.

**Reddit:** read each subreddit's self-promotion rules first; many ADHD
subreddits ban promotion outright. Safer places: r/iosapps, r/apps,
r/SideProject, r/productivityapps, r/indiehackers. Lead with the story ("I have
ADHD and built this…"), not the link.

---

## 12. Weekly tracker

Copy into Numbers/Sheets. Fill in every **Monday** using **the previous 7 days**
(App Analytics → date range → *Last 7 days*).

| Week of | Impressions | Page views | Downloads | Page → DL % | Search views | Search DL | Browse DL | Referrer DL | Ratings (total) | Trials started | Paid | Notes (what changed) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Oct 13 (baseline) | | | | | | | | | 1 | | | before Phase 0 |
| | | | | | | | | | | | | |

**Where each number lives:**
- App Store Connect → **Analytics** (or **Apps → Orbit → App Analytics**) →
  **Metrics** → pick the metric → **View by: Source Type** for the source
  split, or **View by: Product Page** for CPP results.
- Trials and paid: RevenueCat → **Overview** and **Customers**.

**Decision rules:**
- Page → download % **not above 16% after 3 weeks** → try Option B's
  subtitle, or a different slot 1 screenshot.
- Search page views **not up 50% after 3 weeks** → re-check keyword
  popularity in Apple Ads and swap the weakest 3–4 keywords.
- A CPP page converting **better than the default** → use its slot 1 on the
  default page.

---

## 13. Calendar

| When | What | Time |
|---|---|---|
| **Day 1** | Promotional text (Step 1). Optional Apple Ads popularity check. Pick Option A/B/C. Send Spanish/Portuguese text to a proofreader. Send rating-request messages. | 1–1.5 h |
| **Days 2–4** | Produce the new screenshots (section 5). | 2–3 h |
| **Day 5** | Upload build 1.0.2, fill in App Store Connect, submit (Steps 2–7). | 1.5 h |
| **Days 6–7** | Apple review. Website fixes (section 9). First 1–2 social videos. | 1 h |
| **Week 2** | Release. Watch rankings. Create the 4 Custom Product Pages. Start the icon test. | 1 h |
| **Weeks 2–6** | 3 videos/week. Weekly tracker every Monday. No listing changes until week 3. | 2–3 h/week |
| **Week 3** | First real read of results. Apply the decision rules. | 30 min |
| **Week 6** | Phase 0 review together. Then Phase 1 (rating prompt, onboarding paywall, trial experience). | — |

---

## 14. Don'ts

- ❌ Competitor names or trademarks anywhere in metadata (guideline 2.3.7).
- ❌ Medical claims ("treats ADHD", "clinically proven"). "For ADHD minds" is a
  description of the audience, which is fine. Claiming treatment isn't.
- ❌ Offering anything in exchange for ratings (guideline 5.6).
- ❌ Claiming Spanish/Portuguese **app UI** — the descriptions say the UI is
  English.
- ❌ Changing the listing again within 14 days of a change.
- ❌ Running more than one variable at a time in Product Page Optimization at
  this traffic level.

---

## 15. Decisions I need from you

1. **Option A, B or C?** (Recommended: A.)
2. **Should I make the website changes** in section 9 (banner, QR, `/get`
   redirect, meta tags)? You'd only need to redeploy on Netlify.
3. **What happened on Aug 9–10, Sep 17, Sep 23 and Oct 7?** If those were
   specific posts, tell me the platform and format, and I'll shape section 11
   around what already worked.
4. **Do you want me to do the version bump** in `project.yml` (Step 2) on this
   branch, so you only need to archive and upload?
