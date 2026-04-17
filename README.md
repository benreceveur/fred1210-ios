# fred1210-ios

Native iOS client for Fred1210 — Swift 5.10+, SwiftUI, iOS 16+.

Replaces the React Native app in fred1210-mobile as of version 2.0.0.

## Architecture

- **Pattern**: MVVM with `ObservableObject` + `@Published` (iOS 16 compatible)
- **Networking**: `swift-openapi-urlsession` generating client code from `fred1210-api-spec` at build time
- **Persistence**: `KeychainAccess` for the Fred host URL
- **Connectivity**: `NWPathMonitor` in `Core/Connectivity/`
- **Theme**: Design tokens in `Core/Theme/Theme.swift`, matching the RN and web palettes

## Folder layout

```
Config/             — per-developer xcconfig (Local.xcconfig is gitignored)
Fred1210/
  App/              — @main entry, root tab bar, connection banner
  Features/
    Chat/           — chat UI + view model
    Dashboard/      — status cards
    Tasks/          — task CRUD
    Voice/          — AVAudioRecorder hold-to-talk
  Core/
    API/            — swift-openapi-generator output (gitignored)
    Networking/     — FredClient wrapping the generated client
    Config/         — FredConfig (keychain-backed host URL)
    Connectivity/   — NWPathMonitor wrapper
    Theme/          — color + spacing + radius tokens
  Resources/
    Assets.xcassets — app icon + launch screen
Fred1210Tests/      — XCTest unit tests
fastlane/           — build + TestFlight automation
```

## Build prerequisites

1. **Xcode 16+** (required)
2. **xcodegen** (`brew install xcodegen`) — generates `Fred1210.xcodeproj` from `project.yml`
3. **Apple Developer account** — with a valid Team ID for signing and TestFlight

## First-time setup

See [`fastlane/SETUP.md`](fastlane/SETUP.md) for the full walkthrough. Short version:

```bash
# Per-developer config (gitignored)
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit with your DEVELOPMENT_TEAM, FRED_DEFAULT_HOST, PRODUCT_BUNDLE_IDENTIFIER

cp fastlane/.env.local.example fastlane/.env.local
# edit with your FASTLANE_APPLE_ID, FASTLANE_TEAM_ID, FASTLANE_APP_IDENTIFIER

# Generate + open the project
xcodegen generate
open Fred1210.xcodeproj
```

The `.xcodeproj`, `Config/Local.xcconfig`, and `fastlane/.env.local` are all gitignored. Regenerate the project after every pull.

## Run tests

In Xcode: `⌘U`.
Or from CLI:
```bash
xcodebuild test -project Fred1210.xcodeproj -scheme Fred1210 \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation -skipMacroValidation
```

## OpenAPI client generation

The `Core/API/` directory is populated at build time by swift-openapi-generator
reading from a pinned version of the `fred1210-api-spec` repo.
Bumping the spec version is deliberate — edit the SPM dependency, regenerate,
update `FredClient` to match any breaking changes.

## Release

See `fastlane/SETUP.md` for TestFlight upload instructions. The `beta` lane runs `xcodegen generate → archive → export IPA → upload_to_testflight`. Build number is managed manually in `project.yml` via `CURRENT_PROJECT_VERSION` — bump it between releases, or override it per-developer in `Config/Local.xcconfig`.
