import XCTest
@testable import PlaySpot

final class MockWorkspace: WorkspaceProtocol {
    var spotifyRunning = false
    var launchCallCount = 0

    func resolvedSpotifyApp() async -> URL? {
        if !spotifyRunning { launchCallCount += 1 }
        return URL(fileURLWithPath: "/Applications/Spotify.app")
    }
}

final class SpotifyControllerTests: XCTestCase {
    func test_whenSpotifyNotRunning_launchesApp() async {
        let workspace = MockWorkspace()
        let controller = await SpotifyController(workspace: workspace)
        await controller.playpause()
        XCTAssertEqual(workspace.launchCallCount, 1)
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

    func test_whenSpotifyNotRunning_commandSentAfterLaunch() async {
        let workspace = MockWorkspace()
        var scriptsSent: [String] = []
        let controller = await SpotifyController(workspace: workspace, onScript: { scriptsSent.append($0) })
        await controller.playpause()
        XCTAssertEqual(workspace.launchCallCount, 1)
        XCTAssertTrue(scriptsSent.contains(where: { $0.contains("playpause") }))
    }
}
