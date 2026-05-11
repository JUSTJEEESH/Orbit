# Orbit

AI-powered second brain for iOS.

## Stack

- SwiftUI (iOS 26+)
- SwiftData + CloudKit private database
- Apple Foundation Models (on-device) with cloud fallback via edge-function proxy
- Swift 6 with strict concurrency

## Requirements

- Xcode 16+
- iOS 26 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
xcodegen generate
open Orbit.xcodeproj
```

The Xcode project is generated from `project.yml`. Edit `project.yml` and the
SwiftPM packages in `Packages/` — do not edit `Orbit.xcodeproj` directly (it is
git-ignored).

## Module map

| Package | Purpose |
| --- | --- |
| `OrbitKit` | Cross-cutting: Logger, Haptics, AppConfig, Clock |
| `OrbitDesignSystem` | Tokens, typography, primitives, motion |
| `OrbitDomain` | Entities, repository protocols, use cases (no framework deps) |
| `OrbitPersistence` | SwiftData models + CloudKit mirror (Phase 1) |
| `OrbitAI` | Foundation Models + cloud fallbacks (Phase 3) |
| `OrbitSearch` | Embeddings + hybrid search (Phase 4) |
| `OrbitMedia` | Audio, OCR, image pipeline (Phase 2) |
| `OrbitHomeFeature` / `OrbitTimelineFeature` / `OrbitSearchFeature` / `OrbitCaptureFeature` / `OrbitSettingsFeature` | Feature modules |

## Documentation

- `PRODUCT_REQUIREMENTS.md` — product vision and feature scope
- `DESIGN_SYSTEM.md` — visual + motion language
- `ARCHITECTURE.md` — layered architecture rules
- `CLAUDE.md` — authoritative engineering rules
- `ROADMAP.md` — phased delivery plan