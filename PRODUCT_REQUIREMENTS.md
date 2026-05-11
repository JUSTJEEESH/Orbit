Product Requirements Document (PRD)

Project Codename: “Orbit”

AI-Powered Second Brain for iOS

⸻

1. PRODUCT OVERVIEW

Vision

Orbit is an AI-powered personal memory operating system designed to replace the chaotic “chat with yourself” workflow many users rely on in apps like WhatsApp, Telegram, Notes, or iMessage.

Orbit allows users to instantly capture thoughts, links, screenshots, voice notes, reminders, locations, tasks, and ideas with near-zero friction while intelligently organizing and resurfacing information using AI.

The core emotional value:

“I never have to worry about forgetting something important again.”

Orbit should feel:

* Fast
* Calm
* Beautiful
* Intelligent
* Personal
* Native to Apple ecosystem
* Emotionally satisfying

This is NOT:

* another notes app
* another productivity app
* another Notion clone

This IS:

* an intelligent external memory system.

⸻

2. PRIMARY GOALS

MVP Goals

* Fast capture system
* AI auto organization
* Natural language search
* Beautiful Apple-quality UX
* Offline-first architecture
* iCloud sync
* Share sheet support
* Voice capture
* Smart reminders

Long-Term Goals

* Personal AI memory assistant
* Life timeline visualization
* AI recall engine
* Emotional journaling
* Cross-device ecosystem
* Apple Design Award quality

⸻

3. TARGET USERS

Primary Users

1. ADHD / Neurodivergent Users

People overwhelmed by:

* tabs
* screenshots
* saved posts
* forgotten ideas
* mental clutter

2. Creatives

* designers
* writers
* entrepreneurs
* musicians
* developers

3. Busy Professionals

People constantly saving:

* links
* reminders
* screenshots
* notes
* voice memos

4. Apple Power Users

Users already deep in:

* widgets
* shortcuts
* iCloud
* Apple ecosystem

⸻

4. CORE PRODUCT PHILOSOPHY

Principles

1. Capture First

Users should never lose momentum.

2. AI Should Reduce Work

Users should NOT organize manually.

3. Everything Feels Instant

Animations, search, transitions.

4. Emotion Matters

The app should feel calming and relieving.

5. Beautiful Enough To Show Off

Users should WANT to share screenshots.

6. Native iOS Experience

No web-app feeling.

⸻

5. CORE FEATURES

FEATURE 1 — UNIVERSAL CAPTURE

Description

Users can save anything instantly.

Capture Types

* Text
* Voice notes
* Photos
* Screenshots
* Videos
* URLs
* PDFs
* Locations
* Clipboard
* Tasks
* Reminders

Input Methods

* Main app
* Share sheet
* Widget
* Lock screen
* Siri Shortcut
* Apple Watch
* Action Button
* Drag & Drop
* Pasteboard detection

UX Requirements

* Capture in under 2 seconds
* Minimal taps
* Auto-save drafts
* Haptic feedback
* Smooth transitions

⸻

FEATURE 2 — AI AUTO ORGANIZATION

Description

AI automatically organizes captured content.

AI Actions

* Categorization
* Tagging
* Summarization
* Priority scoring
* Task extraction
* Date detection
* Location detection
* Topic clustering
* Semantic relationships

Example

Input:

“Need to renew passport before July Guatemala trip”

Output:

* Creates reminder
* Tags “travel”
* Extracts “passport”
* Suggests checklist

AI Models

Initial:

* OpenAI API

Future:

* Hybrid local + cloud
* Apple Foundation Models
* On-device inference

⸻

FEATURE 3 — NATURAL LANGUAGE SEARCH

Description

Users search conversationally.

Examples

* “Show me restaurant ideas from Roatan”
* “Find the drone business idea”
* “What did Pamela send me last month?”

Requirements

* Semantic search
* OCR indexing
* Voice transcript indexing
* Fast retrieval
* Context awareness

⸻

FEATURE 4 — SMART SCREENSHOT PROCESSING

Description

Orbit understands screenshots automatically.

OCR Pipeline

Extract:

* text
* prices
* dates
* phone numbers
* events
* addresses

Suggested Actions

* Create reminder
* Add calendar event
* Save contact
* Open maps
* Track package

⸻

FEATURE 5 — VOICE CAPTURE

Description

One-tap voice brain dump.

Workflow

1. Record
2. Auto-transcribe
3. Summarize
4. Extract tasks
5. Auto-organize

Requirements

* Fast startup
* Background recording
* Live waveform
* Whisper transcription
* Offline fallback later

⸻

FEATURE 6 — MEMORY TIMELINE

Description

Visual timeline of saved memories.

Includes

* notes
* photos
* voice notes
* locations
* tasks
* completed reminders

UX

* fluid scrolling
* immersive cards
* emotional feel
* Apple Journal inspiration

⸻

FEATURE 7 — AI RECALL ENGINE

Description

AI resurfaces forgotten information.

Examples

* “You mentioned sourdough 5 times this month.”
* “This unfinished task has been ignored.”

Features

* memory resurfacing
* contextual reminders
* intelligent resurfacing
* pattern recognition

⸻

FEATURE 8 — SHARE SHEET EXTENSION

Supported Apps

* Safari
* Reddit
* TikTok
* Instagram
* YouTube
* Photos
* Maps

Processing

* summarize articles
* extract metadata
* detect content type
* auto-tag

⸻

FEATURE 9 — WIDGET SYSTEM

Widgets

* Quick Capture
* Today Summary
* Recent Memories
* Voice Button
* AI Suggestions
* Reminder Queue

Sizes

* Small
* Medium
* Large
* Lock screen widgets

⸻

FEATURE 10 — DAILY AI RECAP

Every Evening

Generate:

* completed tasks
* unfinished items
* captured ideas
* mood patterns
* important moments

⸻

6. DESIGN REQUIREMENTS

DESIGN PHILOSOPHY

Orbit should feel:

* luxurious
* tactile
* alive
* emotionally calming

Inspiration

* Apple Journal
* Things 3
* Craft
* Arc Search
* Not Boring apps

⸻

VISUAL STYLE

UI Characteristics

* soft translucency
* subtle gradients
* layered depth
* floating cards
* smooth shadows
* cinematic typography

Motion Design

* spring animations
* gesture-based navigation
* buttery transitions
* responsive haptics

⸻

COLOR SYSTEM

Themes

* Dark mode first
* Warm ambient tones
* OLED-friendly blacks

Accent Options

* Aurora Blue
* Sunset Orange
* Cosmic Purple
* Forest Green

⸻

TYPOGRAPHY

Font

* SF Pro
* Large editorial headers
* Dynamic Type support

⸻

7. TECH STACK

FRONTEND

Framework

SwiftUI ONLY

Minimum iOS

iOS 18+

Architecture

MVVM + Clean Architecture

State Management

* Observable
* SwiftData
* Async/Await

⸻

BACKEND

Initial Backend

Firebase

Services:

* Authentication
* Firestore
* Storage
* Analytics
* Cloud Functions

⸻

DATABASE

Local

SwiftData

Cloud

Firestore

Sync

iCloud + Firebase hybrid

⸻

AI STACK

Initial

OpenAI API

Models:

* GPT-4.1 mini
* Whisper API
* embeddings API

Future

* Apple Foundation Models
* Local embeddings
* On-device semantic search

⸻

SEARCH SYSTEM

Requirements

* vector embeddings
* semantic retrieval
* local cache
* OCR indexing

⸻

AUTH

Login Options

* Sign in with Apple
* Guest Mode
* Google optional later

⸻

STORAGE

Media

* Firebase Storage
* iCloud backup

⸻

8. APP STRUCTURE

TAB BAR

Tabs

1. Home

* AI feed
* resurfaced memories
* today overview

2. Capture

* instant input hub

3. Timeline

* visual history

4. Search

* conversational retrieval

5. Settings/Profile

⸻

9. USER FLOWS

FLOW 1 — QUICK CAPTURE

1. Open app
2. Tap capture
3. Paste/type/speak
4. AI processes automatically
5. Saved instantly

Target:
< 2 seconds

⸻

FLOW 2 — SHARE SHEET

1. User shares from Safari
2. Orbit extension appears
3. User taps Orbit
4. AI summarizes article
5. Saved automatically

⸻

FLOW 3 — VOICE MEMO

1. Hold capture button
2. Speak naturally
3. Release
4. AI transcribes + organizes

⸻

FLOW 4 — SEARCH

1. User types:

“Find Airbnb ideas”

2. AI retrieves:

* screenshots
* notes
* links
* conversations

⸻

10. DATABASE MODELS

ENTITY: MEMORY

Fields:

* id
* content
* contentType
* createdAt
* updatedAt
* tags
* embeddings
* mediaURLs
* aiSummary
* aiCategory
* aiPriority
* extractedTasks
* extractedDates
* extractedLocations

⸻

ENTITY: TASK

Fields:

* id
* title
* completed
* dueDate
* linkedMemory
* priority

⸻

ENTITY: AI_INSIGHT

Fields:

* id
* type
* content
* relatedMemories
* generatedAt

⸻

11. AI FEATURES IN DETAIL

AI PROCESSING PIPELINE

Step 1 — Input Classification

Determine:

* note
* reminder
* idea
* screenshot
* article
* voice note

Step 2 — Extraction

Extract:

* entities
* dates
* people
* locations
* actions

Step 3 — Embedding Generation

Create semantic vectors.

Step 4 — Categorization

Auto-assign categories.

Step 5 — Smart Suggestions

Suggest:

* reminders
* events
* related memories

⸻

12. PERFORMANCE REQUIREMENTS

Launch Time

< 1.5 sec

Search Speed

< 300ms local

Animations

60fps minimum

Offline Support

Critical features must work offline.

⸻

13. PRIVACY & SECURITY

Requirements

* End-to-end encryption roadmap
* Local-first philosophy
* No ad tracking
* Minimal analytics
* Transparent AI processing

Compliance

* GDPR
* App Tracking Transparency
* Apple privacy nutrition labels

⸻

14. MONETIZATION

FREE TIER

* limited AI processing
* limited cloud sync
* basic search

PRO ($7.99/month)

* unlimited AI
* advanced recall
* unlimited storage
* voice transcription
* AI recaps

LIFETIME OPTION

$149–199

⸻

15. ROADMAP

PHASE 1 — MVP

Duration: 8–12 weeks

Includes:

* capture
* AI organization
* search
* voice
* share sheet
* sync

⸻

PHASE 2 — POLISH

Duration: 4–6 weeks

Includes:

* animations
* widgets
* lock screen support
* haptics
* onboarding

⸻

PHASE 3 — ADVANCED AI

Duration: 8 weeks

Includes:

* resurfacing
* AI insights
* memory clustering
* recommendation engine

⸻

PHASE 4 — APPLE ECOSYSTEM

Duration: ongoing

Includes:

* Apple Watch
* Mac app
* visionOS
* iPad optimization

⸻

16. APP STORE STRATEGY

Positioning

“Your AI-powered second brain.”

Keywords

* notes
* memory
* reminders
* AI notes
* second brain
* voice notes
* productivity
* organization

Screenshots

Focus on:

* beautiful UI
* AI magic moments
* zero friction capture

⸻

17. SUCCESS METRICS

Retention

Day 30 retention > 35%

Daily Usage

Average 5+ captures/day

Search Success

90% successful retrieval rate

App Store Rating

Target 4.8+

⸻

18. FUTURE FEATURES

Future Ideas

* AI life coach
* collaborative spaces
* smart relationship memory
* memory map visualization
* mood tracking
* wearable AI capture
* visionOS spatial memories
* desktop companion
* browser extension

⸻

19. DEVELOPMENT PRIORITIES

BUILD ORDER

STEP 1

Core architecture

STEP 2

Capture system

STEP 3

Local storage

STEP 4

AI processing

STEP 5

Search

STEP 6

Cloud sync

STEP 7

Polish & animations

STEP 8

Widgets/extensions

⸻

20. FINAL PRODUCT FEEL

Orbit should feel like:

* the future
* emotionally calming
* incredibly intelligent
* effortless
* premium
* deeply personal

The app should create this feeling:

“My mind finally feels less cluttered.”