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
| `OrbitKit` | Cross-cutting: Logger, Haptics, AppConfig |
| `OrbitDesignSystem` | Tokens, typography, primitives, motion |
| `OrbitDomain` | Entities, repository protocols, use cases, OrbitClock |
| `OrbitPersistence` | SwiftData models, App Group store, Spotlight indexer |
| `OrbitAI` | Foundation Models, entity extraction, embeddings, OCR, search |
| `OrbitMedia` | Audio recorder, speech transcriber, link metadata, shared media storage |
| Feature packages | `OrbitHomeFeature` · `OrbitTimelineFeature` · `OrbitSearchFeature` · `OrbitCaptureFeature` · `OrbitSettingsFeature` · `OrbitMemoryDetailFeature` |

## Targets

- `Orbit` — the iOS app
- `OrbitShareExtension` — system Share Sheet handler (text + URL + image)
- `OrbitWidgets` — WidgetKit bundle: Quick Capture (small/medium) + Recent Memory (medium/large)

## App Group

The main app, share extension, and widgets share a SwiftData store via the
App Group `group.com.orbit.app`. The entitlement is declared on all three
targets. In the simulator the group resolves automatically; on device it
must be provisioned in the Apple Developer portal.

If the group container can't be resolved at runtime,
`ModelContainerFactory` degrades to per-app on-disk storage so the main app
still works — extensions just see an empty store until the group becomes
available.

## URL scheme

- `orbit://capture` — opens the capture sheet
- `orbit://search` — switches to the search tab

## Sign in with Apple

The Apple Sign-In entitlement is declared on the Orbit target. SIWA works
in the simulator using the simulator's Apple ID. Tokens persist in the
Keychain under the service `com.orbit.app.account`; only the stable
`user` identifier is stored — name and email are persisted only on the
first sign-in (Apple returns them only once) and only if granted.

## StoreKit testing

`Configuration.storekit` declares three local products
(`com.orbit.app.pro.monthly`, `.yearly`, `.lifetime`) for in-Xcode
testing without an App Store Connect setup. The Orbit scheme references
it via `storeKitConfiguration` so purchases route to the local
configuration. To swap to real products later, point the
`EntitlementService` `productIdentifiers` set at your App Store Connect
IDs (or leave the defaults and create them in App Store Connect).

## Documentation

- `PRODUCT_REQUIREMENTS.md` — product vision and feature scope
- `DESIGN_SYSTEM.md` — visual + motion language
- `ARCHITECTURE.md` — layered architecture rules
- `CLAUDE.md` — authoritative engineering rules
- `ROADMAP.md` — phased delivery plan