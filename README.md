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

### First-time provisioning (real device)

The default identifiers (`com.orbit.app`, `group.com.orbit.app`) live in a
globally-unique namespace you don't own. To install on a real device,
patch the project to your personal IDs:

```bash
./Scripts/setup-identity.sh com.<yourname>.orbit group.com.<yourname>.orbit
xcodegen generate
```

The script (a) rewrites `project.yml`, the three `.entitlements` files,
and the Swift literals that reference the canonical identifiers, and
(b) records your IDs in `Config/Identity.xcconfig` (gitignored).

Then in Xcode, for each of **Orbit**, **OrbitShareExtension**, and
**OrbitWidgets**:

1. **Signing & Capabilities** → set **Team** to your personal team.
2. Xcode registers the new bundle ID + App Group automatically.
3. The Apple Sign-In capability registers automatically too.

### Re-applying after a `git pull`

When upstream changes `project.yml` (for example, adding a new feature
package), the canonical identifiers come back. Re-run the script with
no arguments — it reads `Config/Identity.xcconfig` and re-patches:

```bash
# If git pull complained about local changes, discard them first:
git checkout project.yml App/Resources/Orbit.entitlements \
    Extensions/ShareExtension/Orbit.entitlements \
    Extensions/OrbitWidgets/Orbit.entitlements \
    Extensions/ShareExtension/ShareViewController.swift \
    Extensions/OrbitWidgets/RecentMemoryWidget.swift \
    Packages/OrbitKit/Sources/OrbitKit/AppConfig.swift
git pull
./Scripts/setup-identity.sh
xcodegen generate
```

The simulator works with the default identifiers without provisioning.
The provisioning errors only appear when archiving for a real device.

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

## Theme + alternate icons

Settings → Appearance offers four themes (Aurora / Sunset / Cosmic /
Forest). Each theme tile sets the in-app primary accent **and** tries
to switch the home-screen icon to the matching variant.

The primary AppIcon (Aurora) lives in
`App/Resources/Assets.xcassets/AppIcon.appiconset`. The three alternate
variants are bare PNG files at the bundle root, referenced from
`project.yml`'s `CFBundleAlternateIcons` block.

To activate the alternates, drop these PNGs into `App/Resources/`:

```
App/Resources/
  Orbit-Sunset.png       (120 × 120)
  Orbit-Sunset@2x.png    (180 × 180)
  Orbit-Cosmic.png       (120 × 120)
  Orbit-Cosmic@2x.png    (180 × 180)
  Orbit-Forest.png       (120 × 120)
  Orbit-Forest@2x.png    (180 × 180)
```

iOS picks the right size per device. Each PNG should be the
themed-recolor of the Aurora icon — same artwork, palette swapped.

Until you add the PNGs, the theme picker works for the in-app accent
but the home-screen icon stays put — `IconService.select(_:)`
silently no-ops when the variant isn't bundled.

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

## App Store submission checklist

Before archiving for the App Store, walk through:

**App Store Connect setup**

- Create the app record with the bundle ID you used in
  `rename-identifiers.sh`.
- Create the three in-app products (monthly / yearly / lifetime) with
  matching identifiers from `EntitlementService`.
- Provision the App Group and (when CloudKit lands) the iCloud
  container.

**Compliance**

- ✅ In-app account deletion: Settings → Danger zone → Delete account.
  Required by App Store Review Guideline 5.1.1(v).
- ✅ Sign in with Apple is offered (no other social sign-in present
  means no "must offer SIWA" obligation either way).
- ✅ Microphone, Speech Recognition, and Photo Library usage strings
  are present and user-friendly.
- ❌ Privacy nutrition label needs to be filled in App Store Connect
  (data types collected, linked to identity, used for tracking — all
  "Not collected" for Orbit at launch).

**Testing**

- Cold-launch under one second.
- Capture → enrichment → Timeline updates without main-thread hitches.
- Capture from Share Extension persists after force-quitting the app.
- Widgets refresh after capture (within ~5 seconds).
- Sign in with Apple flow works on a real device.
- Delete account confirmation actually wipes everything and returns
  to onboarding.
- Reduce Motion: enable in Settings → Accessibility → Motion. Hero
  transitions should be flat, page transitions instant.
- Dynamic Type: set system to XXL. No layouts crop or truncate.

**Performance with Instruments**

Profile the Orbit scheme with the **Points of Interest** instrument.
`OrbitSignpost.measure(_:_:)` spans bracket the critical paths so they
show up automatically.

## Documentation

- `PRODUCT_REQUIREMENTS.md` — product vision and feature scope
- `DESIGN_SYSTEM.md` — visual + motion language
- `ARCHITECTURE.md` — layered architecture rules
- `CLAUDE.md` — authoritative engineering rules
- `ROADMAP.md` — phased delivery plan