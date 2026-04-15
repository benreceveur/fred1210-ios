# fred1210-ios

Native iOS client for [Fred1210](https://github.com/benreceveur/Fred1210) — Swift 5.10+, SwiftUI, iOS 16+.

Replaces the React Native app in [fred1210-mobile](https://github.com/benreceveur/fred1210-mobile) as of version 2.0.0.

## Architecture

- **Pattern**: MVVM with `ObservableObject` + `@Published` (iOS 16 compatible)
- **Networking**: `swift-openapi-urlsession` generating client code from `fred1210-api-spec` at build time
- **Persistence**: `KeychainAccess` for the Fred host URL
- **Connectivity**: `NWPathMonitor` in `Core/Connectivity/`
- **Theme**: Design tokens in `Core/Theme/Theme.swift`, matching the RN and web palettes

## Folder layout

```
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
```

## Build prerequisites

1. **Xcode 15+** (required — not installed on this Mac by default)
2. **xcodegen** (`brew install xcodegen`) — generates `Fred1210.xcodeproj` from `project.yml`
3. **Apple Developer account** — reuses team `HSG4U9S69K` (already set up for the RN app)

## Generate and open the project

```bash
cd /Users/bob/fred1210-ios
xcodegen generate
open Fred1210.xcodeproj
```

The `.xcodeproj` is **not committed** — regenerate it after pulling. See `.gitignore`.

## Run tests

In Xcode: `⌘U`.  
Or from CLI once Xcode is installed:
```bash
xcodebuild test -project Fred1210.xcodeproj -scheme Fred1210 -destination "platform=iOS Simulator,name=iPhone 15"
```

## OpenAPI client generation

The `Core/API/` directory is populated at build time by swift-openapi-generator
reading from a pinned version of the [fred1210-api-spec](https://github.com/benreceveur/fred1210-api-spec) repo.
Bumping the spec version is deliberate — edit the SPM dependency, regenerate,
update `FredClient` to match any breaking changes.

## Release

Future work (task #20): Fastlane with match/gym/pilot. Reuses ASC app `6762132909`, Apple ID `receveur123@gmail.com`, team `HSG4U9S69K`. Version `2.0.0` build `1` is the cutover from the RN app's build `7`.
