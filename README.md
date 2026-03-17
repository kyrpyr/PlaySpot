# PlaySpot

![Tests](https://github.com/kyrpyr/PlaySpot/actions/workflows/tests.yml/badge.svg)

macOS utility that intercepts media keys (play/pause, next, previous) and redirects them to Spotify — even when other apps try to capture them.

## Features

- Intercepts media keys and redirects them to Spotify
- Menu bar icon with enable/disable toggle
- Launch at login
- Remembers state between launches
- macOS 13.0+

## Install

1. Download `PlaySpot.zip` from [Releases](https://github.com/kyrpyr/PlaySpot/releases)
2. Unzip and move `PlaySpot.app` to Applications
3. Open the app — macOS will show a warning since it's not signed
4. Go to System Settings → Privacy & Security, scroll down and click "Open Anyway"
5. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)

## Build from source

1. Open `PlaySpot.xcodeproj` in Xcode
2. Build and run (Cmd+R)
3. Grant Accessibility permission when prompted

## How it works

PlaySpot installs a system-level event tap that captures media key events before they reach other apps. When a media key is pressed, PlaySpot forwards the command to Spotify using AppleScript. If Spotify isn't running, it launches automatically.

## Updating

When installing a new version, macOS may not recognize the existing Accessibility permission. Reset it by running:

```
tccutil reset Accessibility com.local.PlaySpot
```

Or remove PlaySpot manually in System Settings → Privacy & Security → Accessibility, then re-grant on next launch.

## Permissions

- **Accessibility** — required to intercept media key events
- **Apple Events** — required to send commands to Spotify

## License

MIT
