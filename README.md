# PlaySpot

macOS utility that intercepts media keys (play/pause, next, previous) and redirects them to Spotify — even when other apps try to capture them.

## Features

- Intercepts system media keys via CGEvent tap
- Sends commands to Spotify via AppleScript
- Menu bar icon with enable/disable toggle
- Launch at login support
- Remembers state between launches
- Requires macOS 13.0+

## Setup

1. Open `PlaySpot.xcodeproj` in Xcode
2. Build and run (Cmd+R)
3. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)

## How it works

PlaySpot installs a system-level event tap that captures media key events before they reach other apps. When a media key is pressed, PlaySpot forwards the command to Spotify using AppleScript. If Spotify isn't running, it launches automatically.

## Permissions

- **Accessibility** — required to intercept media key events
- **Apple Events** — required to send commands to Spotify

## License

MIT
