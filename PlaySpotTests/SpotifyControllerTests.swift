import XCTest
@testable import PlaySpot

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
