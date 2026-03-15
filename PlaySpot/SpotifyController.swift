import AppKit

protocol WorkspaceProtocol {
    func launchApp(bundleIdentifier: String)
    func isAppRunning(bundleIdentifier: String) -> Bool
}

extension NSWorkspace: WorkspaceProtocol {
    func launchApp(bundleIdentifier: String) {
        // Prefer LS lookup; fall back to well-known paths if the LS database is stale.
        if let url = resolvedURL(for: bundleIdentifier) {
            openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func isAppRunning(bundleIdentifier: String) -> Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .isEmpty == false
    }

    private func resolvedURL(for bundleIdentifier: String) -> URL? {
        if let url = urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }
        // LS didn't find it — search standard install locations by bundle ID.
        let candidates: [String]
        switch bundleIdentifier {
        case "com.spotify.client":
            let home = NSHomeDirectory()
            candidates = ["\(home)/Applications/Spotify.app", "/Applications/Spotify.app"]
        default:
            return nil
        }
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.fileExists(atPath: $0.path) }
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
        run(command: "playpause")
    }

    func nextTrack() {
        if !ensureRunning() { return }
        run(command: "next track")
    }

    func previousTrack() {
        if !ensureRunning() { return }
        run(command: "previous track")
    }

    // Returns true if Spotify is already running.
    // If not running: launches it, schedules a delayed playpause, returns false.
    @discardableResult
    private func ensureRunning() -> Bool {
        guard workspace.isAppRunning(bundleIdentifier: spotifyBundleId) else {
            workspace.launchApp(bundleIdentifier: spotifyBundleId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.run(command: "playpause")
            }
            return false
        }
        return true
    }

    // Builds a path-based AppleScript reference so the command works even when
    // Spotify's path isn't in the Launch Services database.
    private func spotifyAppPath() -> String? {
        // Mirror the same search order used by launchApp.
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spotifyBundleId) {
            return url.path
        }
        let home = NSHomeDirectory()
        return ["\(home)/Applications/Spotify.app", "/Applications/Spotify.app"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    // Must be called on main thread — all callers dispatch to main via MediaKeyInterceptor.
    private func run(command: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        // Use the full path as the application reference so AppleScript doesn't
        // need to resolve the name through Launch Services (which may not have Spotify).
        let appRef = spotifyAppPath().map { "\"\($0)\"" } ?? "\"Spotify\""
        let script = "tell application \(appRef) to \(command)"
        print("[PlaySpot] run: \(script)")
        if let onScript {
            onScript(script)
            return
        }
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { print("[PlaySpot] AppleScript error: \(error)") }
    }
}
