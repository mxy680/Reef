---
name: deploying-reef-ipad
description: Use when building, installing, or running the Reef iOS app on a connected iPad from the command line. Covers build, install, launch, and device discovery without needing Xcode GUI.
---

# Deploying Reef-iOS to iPad (CLI)

## Prerequisites

- Xcode 16.0+ installed
- iPad connected via USB or on same network
- Code signing configured (Team: `SMJLWBZ8X6`, automatic provisioning)
- Secrets symlinked (`./scripts/link-env.sh`)

## 1. Discover Connected Devices

```bash
xcrun devicectl list devices
```

Look for a device with `connected` state. Note the **UUID** (Identifier column).

## 2. Build the App

```bash
xcodebuild -project Reef-iOS/Reef.xcodeproj \
  -scheme Reef \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  build
```

The built `.app` lands at: `build/DerivedData/Build/Products/Debug-iphoneos/Reef.app`

**Notes:**
- First build resolves SPM packages (Supabase, GoogleSignIn) and takes longer.
- Add `-quiet` flag to suppress verbose output.
- For release: change `-configuration Debug` to `-configuration Release`.

## 3. Install on iPad

```bash
xcrun devicectl device install app \
  --device <DEVICE_UUID> \
  build/DerivedData/Build/Products/Debug-iphoneos/Reef.app
```

Replace `<DEVICE_UUID>` with the UUID from step 1.

You can also use device name instead of UUID:
```bash
xcrun devicectl device install app \
  --device "iPad Name" \
  build/DerivedData/Build/Products/Debug-iphoneos/Reef.app
```

## 4. Launch the App

```bash
xcrun devicectl device process launch \
  --device <DEVICE_UUID> \
  com.studyreef.app
```

## Quick Reference

| Action | Command |
|--------|---------|
| List devices | `xcrun devicectl list devices` |
| Build (debug) | `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData build` |
| Install | `xcrun devicectl device install app --device <UUID> build/DerivedData/Build/Products/Debug-iphoneos/Reef.app` |
| Launch | `xcrun devicectl device process launch --device <UUID> com.studyreef.app` |
| Screenshot | `pymobiledevice3 developer dvt screenshot --rsd <host> <port> screenshot.png` (requires `sudo pymobiledevice3 remote start-tunnel` first) |

## Build + Install + Launch (One-Liner)

```bash
DEVICE=<DEVICE_UUID> && \
xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData build && \
xcrun devicectl device install app --device "$DEVICE" build/DerivedData/Build/Products/Debug-iphoneos/Reef.app && \
xcrun devicectl device process launch --device "$DEVICE" com.studyreef.app
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Device shows `unavailable` | Reconnect USB, or enable "Connect via network" in Xcode > Window > Devices |
| Code signing error | Open `Reef.xcodeproj` in Xcode once to refresh provisioning profiles |
| SPM resolution fails | Delete `build/DerivedData` and rebuild |
| App won't install | Check iPad is running iOS 18.2+ (`xcrun devicectl list devices` shows model) |
| `build/DerivedData` gitignored? | Add `build/` to `.gitignore` if not already there |

## App Identity

| Item | Value |
|------|-------|
| Bundle ID | `com.studyreef.app` |
| Team ID | `SMJLWBZ8X6` |
| Scheme | `Reef` |
| Min iOS | 18.2 |
| Device family | iPad only |
