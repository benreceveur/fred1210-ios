# Fastlane setup — fred1210-ios

> `fastlane/README.md` is auto-regenerated every run. This file is the human-written setup guide. Don't rename it back.

## One-time setup

### 1. Sign in to Xcode (local machine only)

The first archive will fail unless Xcode has an Apple ID with access to team `HSG4U9S69K`.

1. Open Xcode → **Settings** → **Accounts** → **+** → Apple ID
2. Sign in with `receveur123@gmail.com`
3. Xcode will automatically download the team's provisioning profiles

Verify by running:
```bash
cd /Users/bob/fred1210-ios
xcodegen generate
open Fred1210.xcodeproj
```
In the Fred1210 target's **Signing & Capabilities** tab, you should see **Team: Ben Receveur (HSG4U9S69K)** with automatic signing enabled. No yellow/red warnings.

### 2. App Store Connect API key

This replaces Apple ID + 2FA for programmatic uploads. Generate once, use everywhere.

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **Users and Access** → **Integrations** tab → **Keys** (App Store Connect API)
3. Click **+** to generate a new key
   - Name: `fred1210-ci`
   - Role: **App Manager** (minimum for TestFlight upload)
4. Download the `.p8` file **immediately** — Apple only lets you download it once
5. Note the **Key ID** (10 characters) and **Issuer ID** (UUID at the top of the page)

Store everything in your Keychain:

```bash
security add-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ID -w '<10-char key id>'
security add-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ISSUER_ID -w '<uuid>'
security add-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_KEY -w "$(cat ~/Downloads/AuthKey_XXXXXXX.p8)"
```

Load into your shell before running fastlane:

```bash
export APP_STORE_CONNECT_API_KEY_ID="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ID -w)"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ISSUER_ID -w)"
export APP_STORE_CONNECT_API_KEY_KEY="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_KEY -w)"
```

### 3. GitHub Actions secrets (optional — for CI uploads)

If you want `workflow_dispatch` runs of `.github/workflows/ios-ci.yml` to publish to TestFlight, add these repo secrets (Settings → Secrets and variables → Actions):

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_KEY` — the full `.p8` file contents, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines

Then Actions → iOS CI → Run workflow triggers a TestFlight upload.

## First cutover to 2.0.0

```bash
cd /Users/bob/fred1210-ios

# Load API key (once per shell)
export APP_STORE_CONNECT_API_KEY_ID="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ID -w)"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_ISSUER_ID -w)"
export APP_STORE_CONNECT_API_KEY_KEY="$(security find-generic-password -s fred1210-ios -a APP_STORE_CONNECT_API_KEY_KEY -w)"

# Optional changelog
export TESTFLIGHT_CHANGELOG="2.0.0 — native Swift rewrite. Chat, Dashboard, Tasks, Voice."

fastlane beta
```

Total time: ~15 minutes.
1. xcodegen regenerates the project
2. SPM resolves dependencies
3. swift-openapi-generator runs at build time
4. Archive + export IPA (Release)
5. Upload to TestFlight
6. Apple processing (~5-15 min after upload) → email notification

Open TestFlight on your iPhone and update to 2.0.0.

## Lanes

| Lane | What it does |
|---|---|
| `fastlane test` | Regenerate project + run unit tests on iPhone 16 simulator |
| `fastlane archive` | Signed Release archive → `build/Fred1210.ipa` (no upload) |
| `fastlane beta` | Bump build number + archive + upload to TestFlight |

## Troubleshooting

- **"No profiles for com.relayforgelabs.fred1210 were found"**
  → step 1 (sign in to Xcode) wasn't completed, or the target doesn't have automatic signing enabled. Open `Fred1210.xcodeproj` → Fred1210 target → Signing & Capabilities → check "Automatically manage signing".

- **"Invalid provisioning profile"**
  → delete `~/Library/MobileDevice/Provisioning Profiles/` and let Xcode regenerate on the next build.

- **"Your session has expired"** / 401 from App Store Connect
  → regenerate the API key; Apple keys expire after 1 year.

- **Build fails with "Command SwiftCompile failed"**
  → run `xcodebuild -resolvePackageDependencies` first, then retry. SPM occasionally gets into a bad state after Xcode updates.

- **Upload hangs at "Authenticating with the App Store"**
  → wrong bundle ID or team ID. Verify `Appfile` matches the ASC app record (`app_identifier("com.relayforgelabs.fred1210")`, `team_id("HSG4U9S69K")`).
