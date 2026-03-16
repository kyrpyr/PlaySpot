import AppKit

protocol WorkspaceProtocol {
    /// Returns the Spotify app URL, launching it first if not already running.
    /// Returns nil if Spotify cannot be found on disk.
    func resolvedSpotifyApp() async -> URL?
}

extension NSWorkspace: WorkspaceProtocol {
    func resolvedSpotifyApp() async -> URL? {
        let bundleId = "com.spotify.client"
        let home = NSHomeDirectory()
        let url = urlForApplication(withBundleIdentifier: bundleId)
            ?? ["\(home)/Applications/Spotify.app", "/Applications/Spotify.app"]
                .map(URL.init(fileURLWithPath:))
                .first(where: { FileManager.default.fileExists(atPath: $0.path) })
        guard let url else { return nil }

        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty {
            _ = try? await openApplication(at: url, configuration: .init())
        }
        return url
    }
}

@MainActor
final class SpotifyController {
    private let workspace: WorkspaceProtocol
    // onScript: injectable for testing
    private let onScript: ((String) -> Void)?

    init(workspace: WorkspaceProtocol = NSWorkspace.shared, onScript: ((String) -> Void)? = nil) {
        self.workspace = workspace
        self.onScript = onScript
    }

    func playpause() async { await send("playpause") }
    func nextTrack() async { await send("next track") }
    func previousTrack() async { await send("previous track") }

    private func send(_ command: String) async {
        guard let url = await workspace.resolvedSpotifyApp() else { return }
        let script = "tell application \"\(url.path)\" to \(command)"
        if let onScript { onScript(script); return }
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
