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
        let trusted = AXIsProcessTrusted()
        print("[PlaySpot] launch: AXIsProcessTrusted=\(trusted) path=\(Bundle.main.bundlePath)")
        appState.hasAccessibilityPermission = trusted
        let savedEnabled = UserDefaults.standard.bool(forKey: "interceptionEnabled")
        if savedEnabled {
            appState.interceptionEnabled = true  // will no-op if no permission
        }

        // Observe state changes via Combine.
        // dropFirst() skips the initial value — we call syncInterceptor() explicitly below.
        // NOTE: @Published fires BEFORE the property is updated, so we must use the
        // emitted value rather than re-reading appState.status inside the sink.
        appState.$status
            .dropFirst()
            .sink { [weak self] newStatus in
                self?.syncInterceptor(for: newStatus)
                self?.updateMenuBar()
            }
            .store(in: &cancellables)

        appState.$showInMenuBar
            .dropFirst()
            .sink { [weak self] _ in self?.updateMenuBar() }
            .store(in: &cancellables)

        syncInterceptor(for: appState.status)
        updateMenuBar()
    }

    private func syncInterceptor(for status: InterceptionStatus) {
        print("[PlaySpot] syncInterceptor: status=\(status)")
        if status == .active {
            let ok = interceptor.enable()
            if !ok {
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app running when the window is closed — user may still want the menu bar item
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        interceptor.disable()
    }

    @objc private func statusItemClicked() {
        // Find a key-capable window (may be hidden after user closed it but not quit)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
