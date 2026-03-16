import AppKit

protocol WorkspaceProtocol {
    func launchApp(bundleIdentifier: String) async
    func isAppRunning(bundleIdentifier: String) -> Bool
}

extension NSWorkspace: WorkspaceProtocol {
    func launchApp(bundleIdentifier: String) async {
        // Prefer LS lookup; fall back to well-known paths if the LS database is stale.
        guard let url = resolvedURL(for: bundleIdentifier) else { return }
        _ = try? await openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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

@MainActor
final class SpotifyController {
    private let spotifyBundleId = "com.spotify.client"
    private let workspace: WorkspaceProtocol
    // onScript: injectable for testing
    private let onScript: ((String) -> Void)?

    init(workspace: WorkspaceProtocol = NSWorkspace.shared, onScript: ((String) -> Void)? = nil) {
        self.workspace = workspace
        self.onScript = onScript
    }

    func playpause() async {
        await ensureRunning()
        run(command: "playpause")
    }

    func nextTrack() async {
        guard workspace.isAppRunning(bundleIdentifier: spotifyBundleId) else {
            await workspace.launchApp(bundleIdentifier: spotifyBundleId)
            run(command: "playpause")
            return
        }
        run(command: "next track")
    }

    func previousTrack() async {
        guard workspace.isAppRunning(bundleIdentifier: spotifyBundleId) else {
            await workspace.launchApp(bundleIdentifier: spotifyBundleId)
            run(command: "playpause")
            return
        }
        run(command: "previous track")
    }

    // Launches Spotify if not running and waits for it to finish launching.
    private func ensureRunning() async {
        guard !workspace.isAppRunning(bundleIdentifier: spotifyBundleId) else { return }
        await workspace.launchApp(bundleIdentifier: spotifyBundleId)
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

    private func run(command: String) {
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
