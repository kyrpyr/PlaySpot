import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu = NSMenu()
    private var toggleMenuItem: NSMenuItem?
    private let interceptor = MediaKeyInterceptor()
    private let spotify = SpotifyController()
    private var cancellables = Set<AnyCancellable>()
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire interceptor callbacks
        interceptor.onKey = { [weak self] key in
            Task {
                switch key {
                case .playPause: await self?.spotify.playpause()
                case .next:      await self?.spotify.nextTrack()
                case .previous:  await self?.spotify.previousTrack()
                }
            }
        }

        // Check permission and restore saved state
        appState.hasAccessibilityPermission = AXIsProcessTrusted()
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
                guard let self else { return }
                self.syncInterceptor(for: newStatus)
                self.updateMenuBar(status: newStatus, showInMenuBar: self.appState.showInMenuBar)
            }
            .store(in: &cancellables)

        appState.$showInMenuBar
            .dropFirst()
            .sink { [weak self] newShowInMenuBar in
                guard let self else { return }
                self.updateMenuBar(status: self.appState.status, showInMenuBar: newShowInMenuBar)
            }
            .store(in: &cancellables)

        syncInterceptor(for: appState.status)
        updateMenuBar(status: appState.status, showInMenuBar: appState.showInMenuBar)
    }

    private func syncInterceptor(for status: InterceptionStatus) {
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

    private func updateMenuBar(status: InterceptionStatus, showInMenuBar: Bool) {
        if showInMenuBar {
            let isActive = status == .active
            if statusItem == nil {
                let item = NSMenuItem(title: "", action: #selector(toggleInterception), keyEquivalent: "")
                item.target = self
                statusMenu.addItem(item)
                statusMenu.addItem(.separator())
                statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                toggleMenuItem = item

                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                statusItem?.button?.action = #selector(statusItemClicked)
                statusItem?.button?.target = self
            }
            toggleMenuItem?.title = isActive ? "Disable Interception" : "Enable Interception"
            statusItem?.button?.image = NSImage(
                systemSymbolName: isActive ? "music.note" : "music.note.slash",
                accessibilityDescription: nil
            )
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
                statusMenu.removeAllItems()
                toggleMenuItem = nil
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
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleInterception() {
        if appState.status == .active {
            appState.interceptionEnabled = false
        } else {
            let trusted = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            appState.hasAccessibilityPermission = trusted
            if trusted {
                appState.interceptionEnabled = true
            }
        }
    }
}
