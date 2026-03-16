import XCTest
@testable import PlaySpot

// Mock workspace to avoid launching real processes in tests
final class MockWorkspace: WorkspaceProtocol {
    var launchCallCount = 0
    var lastLaunchedBundleId: String?
    var spotifyRunning = false

    func launchApp(bundleIdentifier: String) async {
        launchCallCount += 1
        lastLaunchedBundleId = bundleIdentifier
    }

    func isAppRunning(bundleIdentifier: String) -> Bool {
        return spotifyRunning
    }
}

final class SpotifyControllerTests: XCTestCase {
    func test_whenSpotifyNotRunning_launchesApp() async {
        let workspace = MockWorkspace()  // spotifyRunning = false by default
        let controller = await SpotifyController(workspace: workspace)
        await controller.playpause()
        XCTAssertEqual(workspace.launchCallCount, 1)
        XCTAssertEqual(workspace.lastLaunchedBundleId, "com.spotify.client")
    }

    func test_whenSpotifyRunning_doesNotLaunch() async {
        let workspace = MockWorkspace()
        workspace.spotifyRunning = true
        var scriptsSent: [String] = []
        let controller = await SpotifyController(workspace: workspace, onScript: { scriptsSent.append($0) })
        await controller.playpause()
        XCTAssertEqual(workspace.launchCallCount, 0)
        XCTAssertTrue(scriptsSent.contains(where: { $0.contains("playpause") }))
    }

    func test_whenSpotifyNotRunning_nextTrack_launchesApp() async {
        // next/previous when Spotify is not running: launch + playpause.
        // The playpause after launch is intentional — Spotify resumes last session.
        let workspace = MockWorkspace()
        let controller = await SpotifyController(workspace: workspace)
        await controller.nextTrack()
        XCTAssertEqual(workspace.launchCallCount, 1)
    }

    func test_whenSpotifyNotRunning_previousTrack_launchesApp() async {
        let workspace = MockWorkspace()
        let controller = await SpotifyController(workspace: workspace)
        await controller.previousTrack()
        XCTAssertEqual(workspace.launchCallCount, 1)
    }

    func test_whenSpotifyNotRunning_playpauseSentAfterLaunch() async {
        let workspace = MockWorkspace()
        var scriptsSent: [String] = []
        let controller = await SpotifyController(workspace: workspace, onScript: { scriptsSent.append($0) })
        await controller.playpause()
        XCTAssertEqual(workspace.launchCallCount, 1)
        XCTAssertTrue(scriptsSent.contains(where: { $0.contains("playpause") }))
    }
}
