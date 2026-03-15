# Spotify Media Keys — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app that intercepts system media keys (play/pause, next, previous) and redirects them to Spotify.

**Architecture:** SwiftUI app with `@NSApplicationDelegateAdaptor` for AppKit lifecycle. `AppState` ObservableObject holds all shared state. `MediaKeyInterceptor` installs a CGEvent tap. `SpotifyController` sends AppleScript commands. All components communicate through `AppState`.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, CoreGraphics (CGEvent tap), NSAppleScript, XCTest

---

## File Map

| File | Responsibility |
|---|---|
| `SpotApp/SpotApp.swift` | `@main` entry point, `@NSApplicationDelegateAdaptor` |
| `SpotApp/AppDelegate.swift` | Lifecycle, menu bar `NSStatusItem`, `UserDefaults` restore |
| `SpotApp/AppState.swift` | `ObservableObject`: interception state, permission state, menu bar pref |
| `SpotApp/ContentView.swift` | SwiftUI main window UI |
| `SpotApp/MediaKeyInterceptor.swift` | CGEvent tap: install, remove, key routing |
| `SpotApp/SpotifyController.swift` | AppleScript bridge + Spotify launch logic |
| `SpotAppTests/AppStateTests.swift` | Unit tests for state transitions |
| `SpotAppTests/MediaKeyInterceptorTests.swift` | Unit tests for key-down detection logic |
| `SpotAppTests/SpotifyControllerTests.swift` | Unit tests via protocol mock |

---

## Chunk 1: Project Setup + AppState + SpotifyController

### Task 1: Create Xcode Project

**Files:**
- Create: `SpotApp.xcodeproj` (via Xcode GUI)
- Create: `SpotApp/SpotApp.entitlements`

- [ ] **Step 1: Create project in Xcode**

  Open Xcode → File → New → Project → macOS → App
  - Product Name: `SpotApp`
  - Bundle Identifier: `com.local.SpotApp`
  - Interface: **SwiftUI**
  - Life Cycle: **SwiftUI App** (this generates a `@main` struct conforming to `App`, which is what the architecture uses with `@NSApplicationDelegateAdaptor`)
  - Language: **Swift**
  - Include Tests: **yes**

- [ ] **Step 2: Disable App Sandbox**

  Project navigator → SpotApp target → Signing & Capabilities → remove "App Sandbox" (CGEvent tap is blocked by sandbox). If Hardened Runtime is present, keep it.

  > Note: with App Sandbox removed, no special entitlements are required for AppleScript to work. The `SpotApp.entitlements` file may be empty or deleted.

- [ ] **Step 3: Build and run**

  `Cmd+R` — app should launch and show a default SwiftUI window. Fix any build errors before continuing.

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: create Xcode project skeleton"
  ```

---

### Task 2: AppState

**Files:**
- Create: `SpotApp/AppState.swift`
- Create: `SpotAppTests/AppStateTests.swift`

- [ ] **Step 1: Write failing tests**

  Replace the contents of `SpotAppTests/AppStateTests.swift`:

  ```swift
  import XCTest
  @testable import SpotApp

  final class AppStateTests: XCTestCase {
      func test_initialState_isInactive() {
          let state = AppState()
          XCTAssertFalse(state.interceptionEnabled)
          XCTAssertEqual(state.status, .inactive)
      }

      func test_setEnabled_updatesStatus() {
          let state = AppState()
          state.hasAccessibilityPermission = true  // explicit — don't rely on default
          state.interceptionEnabled = true
          XCTAssertEqual(state.status, .active)
      }

      func test_setDisabled_updatesStatus() {
          let state = AppState()
          state.hasAccessibilityPermission = true
          state.interceptionEnabled = true
          state.interceptionEnabled = false
          XCTAssertEqual(state.status, .inactive)
      }

      func test_noPermission_blocksEnable() {
          let state = AppState()
          state.hasAccessibilityPermission = false
          state.interceptionEnabled = true
          XCTAssertEqual(state.status, .noPermission)
          XCTAssertFalse(state.interceptionEnabled)
      }

      func test_showInMenuBar_persistsToUserDefaults() {
          let defaults = UserDefaults.standard
          defaults.removeObject(forKey: "showInMenuBar")
          let state = AppState()
          state.showInMenuBar = true
          XCTAssertTrue(defaults.bool(forKey: "showInMenuBar"))
          state.showInMenuBar = false
          XCTAssertFalse(defaults.bool(forKey: "showInMenuBar"))
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  `Cmd+U` in Xcode or:
  ```bash
  xcodebuild test -project SpotApp.xcodeproj -scheme SpotApp -destination 'platform=macOS'
  ```
  Expected: compile error — `AppState` not found.

- [ ] **Step 3: Implement AppState**

  Create `SpotApp/AppState.swift`:

  ```swift
  import Foundation
  import Combine

  enum InterceptionStatus {
      case active
      case inactive
      case noPermission
  }

  final class AppState: ObservableObject {
      @Published var showInMenuBar: Bool {
          didSet { UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar") }
      }

      @Published var hasAccessibilityPermission: Bool = true

      @Published private(set) var status: InterceptionStatus = .inactive

      var interceptionEnabled: Bool {
          get { _interceptionEnabled }
          set {
              objectWillChange.send()  // required: plain var doesn't trigger @Published
              guard newValue else {
                  _interceptionEnabled = false
                  status = .inactive
                  UserDefaults.standard.set(false, forKey: "interceptionEnabled")
                  return
              }
              guard hasAccessibilityPermission else {
                  status = .noPermission
                  return
              }
              _interceptionEnabled = true
              status = .active
              UserDefaults.standard.set(true, forKey: "interceptionEnabled")
          }
      }

      private var _interceptionEnabled: Bool = false

      init() {
          showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
          // Note: `interceptionEnabled` is intentionally NOT restored here.
          // AppDelegate restores it after checking AXIsProcessTrusted() at launch.
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

  ```bash
  xcodebuild test -project SpotApp.xcodeproj -scheme SpotApp -destination 'platform=macOS'
  ```
  Expected: all `AppStateTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SpotApp/AppState.swift SpotAppTests/AppStateTests.swift
  git commit -m "feat: add AppState with interception status and UserDefaults persistence"
  ```

---

### Task 3: SpotifyController

**Files:**
- Create: `SpotApp/SpotifyController.swift`
- Create: `SpotAppTests/SpotifyControllerTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `SpotAppTests/SpotifyControllerTests.swift`:

  ```swift
  import XCTest
  @testable import SpotApp

  // Mock workspace to avoid launching real processes in tests
  final class MockWorkspace: WorkspaceProtocol {
      var launchCallCount = 0
      var lastLaunchedBundleId: String?

      func launchApp(bundleIdentifier: String) {
          launchCallCount += 1
          lastLaunchedBundleId = bundleIdentifier
      }

      func isAppRunning(bundleIdentifier: String) -> Bool {
          return false // Spotify not running by default
      }
  }

  final class SpotifyControllerTests: XCTestCase {
      func test_whenSpotifyNotRunning_launchesApp() {
          let workspace = MockWorkspace()
          let controller = SpotifyController(workspace: workspace)
          controller.playpause()
          XCTAssertEqual(workspace.launchCallCount, 1)
          XCTAssertEqual(workspace.lastLaunchedBundleId, "com.spotify.client")
      }

      func test_whenSpotifyNotRunning_nextTrack_launchesApp() {
          // next/previous when Spotify is not running: launch + delayed playpause.
          // The playpause after launch is intentional — Spotify resumes last session.
          let workspace = MockWorkspace()
          let controller = SpotifyController(workspace: workspace)
          controller.nextTrack()
          XCTAssertEqual(workspace.launchCallCount, 1)
      }

      func test_whenSpotifyNotRunning_previousTrack_launchesApp() {
          let workspace = MockWorkspace()
          let controller = SpotifyController(workspace: workspace)
          controller.previousTrack()
          XCTAssertEqual(workspace.launchCallCount, 1)
      }

      func test_whenSpotifyNotRunning_playpauseSentAfterDelay() {
          let workspace = MockWorkspace()
          var scriptsSent: [String] = []
          let controller = SpotifyController(workspace: workspace, onScript: { scriptsSent.append($0) })
          controller.playpause()
          // Immediately after call: launch fired, no script yet
          XCTAssertEqual(workspace.launchCallCount, 1)
          XCTAssertTrue(scriptsSent.isEmpty)
          // After ~2.5s delay: playpause script should have been sent
          let expectation = XCTestExpectation(description: "delayed playpause")
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
              XCTAssertTrue(scriptsSent.contains(where: { $0.contains("playpause") }))
              expectation.fulfill()
          }
          wait(for: [expectation], timeout: 3.0)
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  Expected: compile error — `WorkspaceProtocol`, `SpotifyController` not found.

- [ ] **Step 3: Implement SpotifyController**

  Create `SpotApp/SpotifyController.swift`:

  ```swift
  import AppKit

  protocol WorkspaceProtocol {
      func launchApp(bundleIdentifier: String)
      func isAppRunning(bundleIdentifier: String) -> Bool
  }

  extension NSWorkspace: WorkspaceProtocol {
      func launchApp(bundleIdentifier: String) {
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
          if let url {
              NSWorkspace.shared.openApplication(at: url,
                                                 configuration: NSWorkspace.OpenConfiguration())
          }
      }

      func isAppRunning(bundleIdentifier: String) -> Bool {
          NSRunningApplication
              .runningApplications(withBundleIdentifier: bundleIdentifier)
              .isEmpty == false
      }
  }

  final class SpotifyController {
      private let spotifyBundleId = "com.spotify.client"
      private let workspace: WorkspaceProtocol
      // onScript: injectable for testing the delayed-playpause path
      private let onScript: ((String) -> Void)?

      init(workspace: WorkspaceProtocol = NSWorkspace.shared, onScript: ((String) -> Void)? = nil) {
          self.workspace = workspace
          self.onScript = onScript
      }

      func playpause() {
          if !ensureRunning() { return }
          run(script: "tell application \"Spotify\" to playpause")
      }

      func nextTrack() {
          if !ensureRunning() { return }
          run(script: "tell application \"Spotify\" to next track")
      }

      func previousTrack() {
          if !ensureRunning() { return }
          run(script: "tell application \"Spotify\" to previous track")
      }

      // Returns true if Spotify is already running.
      // If not running: launches it, schedules a delayed playpause, returns false.
      // Note: next/previous when Spotify is not running always start with playpause —
      // this is intentional: Spotify resumes its last session on launch.
      @discardableResult
      private func ensureRunning() -> Bool {
          guard workspace.isAppRunning(bundleIdentifier: spotifyBundleId) else {
              workspace.launchApp(bundleIdentifier: spotifyBundleId)
              DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                  self?.run(script: "tell application \"Spotify\" to playpause")
              }
              return false
          }
          return true
      }

      // Must be called on main thread — all callers dispatch to main via MediaKeyInterceptor.
      private func run(script: String) {
          dispatchPrecondition(condition: .onQueue(.main))
          if let onScript {
              onScript(script)
              return
          }
          var error: NSDictionary?
          NSAppleScript(source: script)?.executeAndReturnError(&error)
          // Errors are intentionally ignored — Spotify may briefly be unavailable
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

  Expected: all `SpotifyControllerTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SpotApp/SpotifyController.swift SpotAppTests/SpotifyControllerTests.swift
  git commit -m "feat: add SpotifyController with launch-if-not-running behavior"
  ```

---

## Chunk 2: MediaKeyInterceptor + UI + Wiring

### Task 4: MediaKeyInterceptor

**Files:**
- Create: `SpotApp/MediaKeyInterceptor.swift`
- Create: `SpotAppTests/MediaKeyInterceptorTests.swift`

- [ ] **Step 1: Write failing tests for key-down detection**

  Create `SpotAppTests/MediaKeyInterceptorTests.swift`:

  ```swift
  import XCTest
  @testable import SpotApp

  final class MediaKeyInterceptorTests: XCTestCase {
      // data1 layout: (keyCode << 16) | keyFlags
      // keyFlags upper byte: 0x0A = key-down, 0x0B = key-up
      // e.g. play key-down:  (16 << 16) | 0x0A10  =>  key-down without autorepeat
      //      play key-up:    (16 << 16) | 0x0B00

      func test_isKeyDown_trueForKeyDownEvent() {
          let data1 = (16 << 16) | 0x0A10  // play key-down
          XCTAssertTrue(MediaKeyInterceptor.isKeyDown(data1: data1))
      }

      func test_isKeyDown_falseForKeyUpEvent() {
          let data1 = (16 << 16) | 0x0B00  // play key-up
          XCTAssertFalse(MediaKeyInterceptor.isKeyDown(data1: data1))
      }

      func test_keyCode_next() {
          let data1 = (17 << 16) | 0x0A10  // next track key-down
          XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 17)
      }

      func test_keyCode_play() {
          let data1 = (16 << 16) | 0x0A10
          XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 16)
      }

      func test_keyCode_previous() {
          let data1 = (18 << 16) | 0x0A10
          XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 18)
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  Expected: compile error — `MediaKeyInterceptor` not found.

- [ ] **Step 3: Implement MediaKeyInterceptor**

  Create `SpotApp/MediaKeyInterceptor.swift`:

  ```swift
  import CoreGraphics
  import AppKit

  final class MediaKeyInterceptor {
      private var eventTap: CFMachPort?
      private var runLoopSource: CFRunLoopSource?

      var onPlayPause: (() -> Void)?
      var onNext: (() -> Void)?
      var onPrevious: (() -> Void)?

      // MARK: - Static helpers (testable without system APIs)

      static func isKeyDown(data1: Int) -> Bool {
          // keyFlags upper byte: 0x0A = key-down, 0x0B = key-up
          return (data1 & 0xFF00) >> 8 == 0x0A
      }

      static func keyCode(from data1: Int) -> Int {
          return (data1 & 0xFFFF0000) >> 16
      }

      // MARK: - Enable / Disable

      func enable() -> Bool {
          guard AXIsProcessTrusted() else { return false }

          let mask = CGEventMask(1 << CGEventType.systemDefined.rawValue)

          guard let tap = CGEvent.tapCreate(
              tap: .cgSessionEventTap,
              place: .headInsertEventTap,
              options: .defaultTap,
              eventsOfInterest: mask,
              callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                  guard let refcon else { return Unmanaged.passRetained(event) }
                  let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                  return interceptor.handle(proxy: proxy, type: type, event: event)
              },
              userInfo: Unmanaged.passUnretained(self).toOpaque()
          ) else {
              return false
          }

          let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
          CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
          CGEventTapEnable(tap, true)

          self.eventTap = tap
          self.runLoopSource = source
          return true
      }

      func disable() {
          if let tap = eventTap {
              CGEventTapEnable(tap, false)
          }
          if let source = runLoopSource {
              CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
          }
          eventTap = nil
          runLoopSource = nil
      }

      // MARK: - Event handling

      private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
          // Handle tap invalidation: macOS auto-disables the tap on timeout.
          // Simply re-enable it. If the tap is permanently broken, AppDelegate's
          // syncInterceptor() will detect failure via enable()'s return value and snap back the UI.
          if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
              if let tap = eventTap { CGEventTapEnable(tap, true) }
              return Unmanaged.passRetained(event)
          }

          guard type == .systemDefined,
                let nsEvent = NSEvent(cgEvent: event),
                nsEvent.subtype.rawValue == 8 else {
              return Unmanaged.passRetained(event)
          }

          let data1 = Int(nsEvent.data1)
          guard Self.isKeyDown(data1: data1) else {
              return nil  // consume key-up silently
          }

          let code = Self.keyCode(from: data1)
          switch code {
          case 16:
              DispatchQueue.main.async { self.onPlayPause?() }
              return nil  // consume
          case 17:
              DispatchQueue.main.async { self.onNext?() }
              return nil
          case 18:
              DispatchQueue.main.async { self.onPrevious?() }
              return nil
          default:
              return Unmanaged.passRetained(event)
          }
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

  Expected: all `MediaKeyInterceptorTests` pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SpotApp/MediaKeyInterceptor.swift SpotAppTests/MediaKeyInterceptorTests.swift
  git commit -m "feat: add MediaKeyInterceptor with CGEvent tap and key-down filtering"
  ```

---

### Task 5: ContentView

**Files:**
- Modify: `SpotApp/ContentView.swift`

- [ ] **Step 1: Replace ContentView with app UI**

  ```swift
  import SwiftUI

  struct ContentView: View {
      @EnvironmentObject var state: AppState
      @State private var showPermissionAlert = false

      var body: some View {
          VStack(spacing: 20) {
              Text(statusText)
                  .font(.headline)
                  .foregroundColor(statusColor)

              Button(toggleLabel) {
                  handleToggle()
              }
              .buttonStyle(.borderedProminent)
              .tint(state.status == .active ? .green : .gray)

              Toggle("Show in Menu Bar", isOn: $state.showInMenuBar)
                  .toggleStyle(.checkbox)
          }
          .padding(30)
          .frame(width: 280)
          .alert("Accessibility Permission Required", isPresented: $showPermissionAlert) {
              Button("Open System Settings") {
                  NSWorkspace.shared.open(
                      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                  )
              }
              Button("Cancel", role: .cancel) {}
          } message: {
              Text("SpotApp needs Accessibility permission to intercept media keys.")
          }
      }

      private var statusText: String {
          switch state.status {
          case .active:      return "Interception active"
          case .inactive:    return "Interception inactive"
          case .noPermission: return "Accessibility permission required"
          }
      }

      private var statusColor: Color {
          state.status == .active ? .green : .secondary
      }

      private var toggleLabel: String {
          state.status == .active ? "Disable interception" : "Enable interception"
      }

      private func handleToggle() {
          if state.status == .active {
              state.interceptionEnabled = false
          } else {
              guard state.hasAccessibilityPermission else {
                  showPermissionAlert = true
                  return
              }
              state.interceptionEnabled = true
          }
      }
  }
  ```

- [ ] **Step 2: Build and check for compile errors**

  `Cmd+B`

- [ ] **Step 3: Commit**

  ```bash
  git add SpotApp/ContentView.swift
  git commit -m "feat: add ContentView with toggle button and menu bar checkbox"
  ```

---

### Task 6: AppDelegate + SpotApp Entry Point

**Files:**
- Create: `SpotApp/AppDelegate.swift`
- Modify: `SpotApp/SpotApp.swift`

- [ ] **Step 1: Implement AppDelegate**

  Create `SpotApp/AppDelegate.swift`:

  ```swift
  import AppKit
  import SwiftUI
  import Combine

  final class AppDelegate: NSObject, NSApplicationDelegate {
      private var statusItem: NSStatusItem?
      private let interceptor = MediaKeyInterceptor()
      private let spotify = SpotifyController()
      private var cancellables = Set<AnyCancellable>()
      let appState = AppState()

      func applicationDidFinishLaunching(_ notification: Notification) {
          // Wire interceptor callbacks
          interceptor.onPlayPause = { [weak self] in self?.spotify.playpause() }
          interceptor.onNext = { [weak self] in self?.spotify.nextTrack() }
          interceptor.onPrevious = { [weak self] in self?.spotify.previousTrack() }

          // Check permission and restore saved state
          appState.hasAccessibilityPermission = AXIsProcessTrusted()
          let savedEnabled = UserDefaults.standard.bool(forKey: "interceptionEnabled")
          if savedEnabled {
              appState.interceptionEnabled = true  // will no-op if no permission
          }

          // Observe state changes via Combine.
          // dropFirst(1) skips the initial value — we call syncInterceptor() explicitly below.
          appState.$status
              .dropFirst()
              .sink { [weak self] _ in
                  self?.syncInterceptor()
                  self?.updateMenuBar()
              }
              .store(in: &cancellables)

          appState.$showInMenuBar
              .dropFirst()
              .sink { [weak self] _ in self?.updateMenuBar() }
              .store(in: &cancellables)

          syncInterceptor()
          updateMenuBar()
      }

      private func syncInterceptor() {
          if appState.status == .active {
              if !interceptor.enable() {
                  // Tap failed to install (e.g. permission was revoked) — snap back UI
                  appState.interceptionEnabled = false
              }
          } else {
              interceptor.disable()
          }
      }

      private func updateMenuBar() {
          if appState.showInMenuBar {
              if statusItem == nil {
                  statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
              }
              let isActive = appState.status == .active
              statusItem?.button?.image = NSImage(
                  systemSymbolName: isActive ? "music.note" : "music.note.slash",
                  accessibilityDescription: nil
              )
              statusItem?.button?.action = #selector(statusItemClicked)
              statusItem?.button?.target = self
          } else {
              if let item = statusItem {
                  NSStatusBar.system.removeStatusItem(item)
                  statusItem = nil
              }
          }
      }

      @objc private func statusItemClicked() {
          NSApp.windows.first?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
      }
  }
  ```

- [ ] **Step 2: Implement SpotApp entry point**

  Replace the contents of `SpotApp/SpotApp.swift`:

  ```swift
  import SwiftUI

  @main
  struct SpotApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

      var body: some Scene {
          WindowGroup {
              ContentView()
                  .environmentObject(delegate.appState)
          }
          .windowResizability(.contentSize)
      }
  }
  ```

- [ ] **Step 3: Build and run**

  `Cmd+R` — app launches, main window visible, toggle button present.

- [ ] **Step 4: Commit**

  ```bash
  git add SpotApp/AppDelegate.swift SpotApp/SpotApp.swift
  git commit -m "feat: wire AppDelegate, MediaKeyInterceptor, and SpotifyController"
  ```

---

### Task 7: Manual Integration Tests

No automated tests here — these require a real keyboard, Spotify, and system permissions.

- [ ] **Step 1: Grant Accessibility permission**

  Run the app → click "Enable interception" → follow the alert → System Settings → Privacy & Security → Accessibility → enable SpotApp.

- [ ] **Step 2: Test play/pause**

  Press ⏯ on keyboard → Spotify should play/pause.

- [ ] **Step 3: Test next/previous**

  Press ⏭ / ⏮ → Spotify should skip tracks.

- [ ] **Step 4: Test Spotify not running**

  Quit Spotify → press ⏯ → Spotify should launch → start playing after ~2s.

- [ ] **Step 5: Test menu bar toggle**

  Check "Show in Menu Bar" → icon appears. Uncheck → icon disappears.

- [ ] **Step 6: Test state persistence**

  Enable interception → quit app → relaunch → interception should still be active.

- [ ] **Step 7: Test permission revocation**

  System Settings → revoke Accessibility for SpotApp → relaunch app → status should show "Accessibility permission required".

- [ ] **Step 8: Test tap invalidation recovery**

  Enable interception → open Activity Monitor → put the system under heavy load for 10–20 seconds. If macOS auto-disables the tap (rare but possible in CI or throttled environments), the app should automatically re-enable it without user action. Status label should remain "Interception active". If the tap cannot be recovered, status should revert to "Interception inactive".

- [ ] **Step 9: Final commit**

  ```bash
  git add .
  git commit -m "feat: complete Spotify media keys app"
  ```
