# Fastlane setup — fred1210-ios

> `fastlane/README.md` is auto-regenerated every run. This file is the human-written setup guide. Don't rename it back.

## One-time setup

### 1. Per-developer config files

This repo doesn't commit any personal identifiers (Apple ID, Team ID, Tailscale hostname). Copy the example templates and fill in your own values:

```bash
cd /path/to/fred1210-ios

# Xcode signing + default host URL
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit Config/Local.xcconfig:
#   DEVELOPMENT_TEAM = <your 10-char Apple Team ID>
#   FRED_DEFAULT_HOST = https://<your-tailscale-host>.ts.net
#   PRODUCT_BUNDLE_IDENTIFIER = <your bundle id, must match ASC app record>

# Fastlane credentials
cp fastlane/.env.local.example fastlane/.env.local
# edit fastlane/.env.local:
#   FASTLANE_APP_IDENTIFIER=<same bundle id as above>
#   FASTLANE_APPLE_ID=<your Apple ID email>
#   FASTLANE_TEAM_ID=<same team id>
```

Both `Config/Local.xcconfig` and `fastlane/.env.local` are gitignored.

### 2. Sign in to Xcode (first-time only)

The first archive will fail unless Xcode has an Apple ID with access to your Apple Developer team.

1. Open Xcode → **Settings** → **Accounts** → **+** → Apple ID
2. Sign in with your Apple Developer account
3. Xcode will automatically download the team's provisioning profiles

Verify by running:
```bash
cd /path/to/fred1210-ios
xcodegen generate
open Fred1210.xcodeproj
```
In the Fred1210 target's **Signing & Capabilities** tab, you should see your team with automatic signing enabled. No yellow/red warnings.

### 3. App-specific password OR ASC API key

For TestFlight uploads, Apple requires either:

**Option A — App-specific password** (quickest, ties to your Apple ID):
1. Go to [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → **App-Specific Passwords**
2. Generate one labelled e.g. `fastlane-fred`
3. Store in Keychain:
   ```bash
   security add-generic-password -U -s fred1210-ios \
     -a APPLE_APP_SPECIFIC_PASSWORD -w '<paste-the-password>'
   ```

**Option B — App Store Connect API key** (CI-ready, not tied to a user):
1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Users and Access → Integrations → Keys → **+**
2. Role: **App Manager**, download the `.p8` file immediately
3. Store in Keychain:
   ```bash
   security add-generic-password -U -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ID -w '<10-char-key-id>'
   security add-generic-password -U -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ISSUER_ID -w '<uuid>'
   security add-generic-password -U -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_KEY -w "$(cat ~/Downloads/AuthKey_*.p8)"
   ```

### 4. GitHub Actions secrets (optional — for CI uploads)

If you want `workflow_dispatch` runs of `.github/workflows/ios-ci.yml` to publish to TestFlight, add these repo secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_KEY` (full `.p8` file contents)

## Lanes

| Lane | What it does |
|---|---|
| `fastlane test` | Regenerate project + run unit tests on iPhone 17 simulator |
| `fastlane archive` | Signed Release archive → `build/Fred1210.ipa` (no upload) |
| `fastlane beta` | Archive + upload to TestFlight |

## Daily cutover

```bash
cd /path/to/fred1210-ios

# Load env (fastlane auto-loads fastlane/.env.local)
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="$(security find-generic-password -s fred1210-ios -a APPLE_APP_SPECIFIC_PASSWORD -w)"

# Optional changelog
export TESTFLIGHT_CHANGELOG="What's new in this build"

fastlane beta
```

## Bumping build numbers

Build number is managed manually in `Config/Local.xcconfig` via `CURRENT_PROJECT_VERSION`. Increment it between releases. No plugin dependency.

## Troubleshooting

- **"No profiles for <bundle-id> were found"** — Xcode hasn't downloaded your team's profiles yet. Open the project in Xcode, click the app target → Signing & Capabilities → make sure "Automatically manage signing" is checked and your team is selected.

- **"Invalid provisioning profile"** — delete `~/Library/MobileDevice/Provisioning Profiles/` and rebuild. Xcode will regenerate.

- **"Please sign in with an app-specific password"** — altool needs `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` set. See step 3A.

- **"invalid curve name" on ASC API key** — known fastlane/Ruby 4 OpenSSL 3 bug. Use Option A (app-specific password) as a workaround, or pin fastlane to Ruby 3.x via a Gemfile.

- **"Missing CFBundleIconName"** — make sure `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is in `project.yml` and you have a 1024x1024 icon at `Fred1210/Resources/Assets.xcassets/AppIcon.appiconset/`.
