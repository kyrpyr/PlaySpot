import XCTest
@testable import PlaySpot

final class MediaKeyInterceptorTests: XCTestCase {
    // data1 layout: (keyCode << 16) | keyFlags
    // keyFlags upper byte: 0x0A = key-down, 0x0B = key-up
    // e.g. play key-down:  (16 << 16) | 0x0A10  =>  key-down without autorepeat
    //      play key-up:    (16 << 16) | 0x0B00

    func test_isKeyDown_trueForKeyDownEvent() {
        let data1 = (16 << 16) | 0x0A10  // play key-down
        XCTAssertTrue(MediaKeyInterceptor.isKeyDown(data1: data1))
    }

    func test_isKeyDown_falseForKeyUpEvent() {
        let data1 = (16 << 16) | 0x0B00  // play key-up
        XCTAssertFalse(MediaKeyInterceptor.isKeyDown(data1: data1))
    }

    func test_keyCode_next() {
        let data1 = (17 << 16) | 0x0A10  // next track key-down
        XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 17)
    }

    func test_keyCode_play() {
        let data1 = (16 << 16) | 0x0A10
        XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 16)
    }

    func test_keyCode_previous() {
        let data1 = (18 << 16) | 0x0A10
        XCTAssertEqual(MediaKeyInterceptor.keyCode(from: data1), 18)
    }
}
