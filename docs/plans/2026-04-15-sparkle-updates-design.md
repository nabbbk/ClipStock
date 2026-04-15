# Sparkle Auto-Update Integration

## Goal

Add a "Check for Updates" button in Settings that uses the Sparkle framework to check GitHub for new versions, download updates in-app, and apply them — bypassing macOS quarantine issues.

## Architecture

### Dependencies

- **Sparkle 2** via SPM (https://github.com/sparkle-project/Sparkle)

### New Files

- `ClipStock/App/UpdaterManager.swift` — ObservableObject wrapping `SPUStandardUpdaterController`. Exposes `checkForUpdates()` and `canCheckForUpdates` for SwiftUI binding.
- `docs/appcast.xml` — Sparkle appcast feed hosted via GitHub Pages. Initial entry for v1.3.1.
- `scripts/sign_and_update_appcast.sh` — Helper script that signs a DMG with Sparkle's `sign_update` tool and appends a new `<item>` to the appcast XML.

### Modified Files

- `ClipStock/Info.plist` — Add `SUFeedURL` (https://nabbbk.github.io/ClipStock/appcast.xml) and `SUPublicEDKey` (generated EdDSA public key).
- `ClipStock/Views/SettingsView.swift` — Add "Updates" section with "Check for Updates" button.
- `ClipStock.xcodeproj` — Sparkle SPM dependency.
- `MARKETING_VERSION` — Verify it matches 1.3.1.

## Data Flow

1. User clicks "Check for Updates" in Settings
2. UpdaterManager calls `SPUStandardUpdaterController.checkForUpdates()`
3. Sparkle fetches `appcast.xml` from GitHub Pages
4. Sparkle compares appcast version to `CFBundleShortVersionString`
5. If newer version exists: Sparkle shows its built-in update dialog (changelog, download progress, install prompt)
6. Sparkle downloads DMG, verifies EdDSA signature, extracts app, replaces current bundle, relaunches
7. No quarantine flag because the download is done by the app, not a browser

## Release Workflow (Post-Integration)

1. Bump `MARKETING_VERSION` in Xcode
2. Build app, create DMG
3. Run `scripts/sign_and_update_appcast.sh <dmg-path> <version> <download-url>`
4. Commit & push updated `docs/appcast.xml`
5. Upload DMG to GitHub Releases

## One-Time Setup (Manual)

1. Run Sparkle's `generate_keys` to create EdDSA key pair
2. Paste public key into `Info.plist` as `SUPublicEDKey`
3. Enable GitHub Pages: repo Settings > Pages > Source: main branch, /docs folder

## Sparkle Config (Info.plist Keys)

| Key | Value |
|-----|-------|
| `SUFeedURL` | `https://nabbbk.github.io/ClipStock/appcast.xml` |
| `SUPublicEDKey` | (generated — placeholder until key generation) |
| `SUEnableAutomaticChecks` | `false` (manual check only, user controls when) |
