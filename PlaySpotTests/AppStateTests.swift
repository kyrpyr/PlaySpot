import XCTest
@testable import PlaySpot

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
