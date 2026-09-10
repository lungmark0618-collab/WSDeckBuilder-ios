import XCTest
@testable import WSDeckBuilder

final class BackSwipePolicyTests: XCTestCase {
    func testOnlyDeliberateLeftSwipeReturns() {
        XCTAssertTrue(BackSwipePolicy.shouldReturn(horizontal: -120, vertical: 15))
        XCTAssertFalse(BackSwipePolicy.shouldReturn(horizontal: 120, vertical: 0))
        XCTAssertFalse(BackSwipePolicy.shouldReturn(horizontal: -30, vertical: 0))
        XCTAssertFalse(BackSwipePolicy.shouldReturn(horizontal: -100, vertical: 110))
        XCTAssertFalse(BackSwipePolicy.shouldReturn(horizontal: 0, vertical: -150))
    }
}
