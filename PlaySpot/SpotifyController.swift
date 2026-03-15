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
