# Spotify Media Keys — Design Spec
**Date:** 2026-03-15

## Overview

Native macOS SwiftUI app that intercepts system media keys (play/pause, next track, previous track) and redirects them to Spotify. The app has a main window with an enable/disable toggle and an option to show/hide a menu bar item.

## Architecture

```
SpotApp (@main SwiftUI, uses @NSApplicationDelegateAdaptor)
├── AppDelegate          — app lifecycle, menu bar NSStatusItem management
├── ContentView          — main window UI
├── MediaKeyInterceptor  — CGEvent tap: install/remove, key routing
└── SpotifyController    — AppleScript bridge: playpause, next, previous
```

## Components

### AppDelegate
- Manages `NSStatusItem` in the menu bar (show/hide based on user preference)
- Persists user preferences via `UserDefaults` (interceptionEnabled, showInMenuBar)
- On launch: if `interceptionEnabled == true`, re-checks `AXIsProcessTrusted()` before re-enabling the tap; falls back to "No permission" state if revoked

### ContentView
- Toggle button: "Enable / Disable interception" (green when active, gray when inactive)
- Checkbox: "Show in Menu Bar"
- Status label: "Interception active" / "Interception inactive" / "Accessibility permission required"
- On first enable attempt without permission: shows alert with "Open System Settings" button

### MediaKeyInterceptor
- Uses `CGEvent.tapCreate` to install a low-level event tap on `CGEventType.systemDefined` (`NX_SYSDEFINED`)
- Intercepts key codes:
  - `NX_KEYTYPE_PLAY` = 16 — play/pause
  - `NX_KEYTYPE_NEXT` = 17 — next track
  - `NX_KEYTYPE_PREVIOUS` = 18 — previous track (the dedicated ⏮ key; distinct from NX_KEYTYPE_REWIND = 20)
- **Key-down filtering:** the callback fires for both key-down and key-up. Only key-down events (`(data1 & 0xFF00) >> 8 == 0xA0`) dispatch a command; key-up events are consumed silently without triggering AppleScript.
- **Thread safety:** the CGEvent tap callback runs on a CFRunLoop thread. All `SpotifyController` calls are dispatched to `DispatchQueue.main`.
- **Tap invalidation:** macOS can auto-disable a tap on timeout. The callback handles `kCGEventTapDisabledByTimeout` and `kCGEventTapDisabledByUserInput` by re-enabling the tap via `CGEventTapEnable` and updating the UI status label if the tap cannot be recovered.
- `enable()` / `disable()` methods install and remove the tap
- Requires Accessibility permission; checks `AXIsProcessTrusted()` before enabling

### SpotifyController
- Sends AppleScript commands via `NSAppleScript` (called on main thread):
  - `tell application "Spotify" to playpause`
  - `tell application "Spotify" to next track`
  - `tell application "Spotify" to previous track`
- **Spotify not running:** if Spotify is not running, launch it via `NSWorkspace.shared.launchApplication(withBundleIdentifier: "com.spotify.client")`, then after a short delay (≈2s) send `playpause` via AppleScript to start playback. next/previous commands while Spotify is not running also trigger launch + playpause.

### Menu Bar Item
- When visible, clicking the `NSStatusItem` icon opens/focuses the main window
- Icon reflects interception state: filled symbol when active, outlined when inactive
- Shown/hidden based on the "Show in Menu Bar" preference

## Data Flow

```
Media key pressed
  → CGEvent tap fires (if active)
    → key-up? → consume silently, return
    → MediaKeyInterceptor identifies key type
      → DispatchQueue.main.async: SpotifyController.playpause() / .next() / .previous()
        → check Spotify running → if yes: NSAppleScript command sent
      → event consumed (nil returned, system does not process it)
```

When interception is disabled, events pass through normally to the system.

## Permissions

- **Accessibility** — required for `CGEvent tap`. Checked at launch and before enabling.
- On first enable attempt without permission: show alert with button "Open System Settings".
- On launch with saved `interceptionEnabled = true`: re-check `AXIsProcessTrusted()`; if revoked, show "No permission" state without crashing.

## UI States

| State | Toggle label | Toggle color | Status label |
|---|---|---|---|
| Active | "Disable interception" | Green | "Interception active" |
| Inactive | "Enable interception" | Gray | "Interception inactive" |
| No permission | "Enable interception" | Gray | "Accessibility permission required" |

## Persistence

`UserDefaults`:
- `interceptionEnabled: Bool` — restored on launch (with permission re-check)
- `showInMenuBar: Bool` — restored on launch

## Out of Scope

- Volume control
- Controlling other music apps
- Custom key bindings
- Launch at login (can be added later via SMAppService)
