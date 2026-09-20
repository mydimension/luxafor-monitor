import XCTest
@testable import LuxaforKit

final class LuxaforColorTests: XCTestCase {
    func testWellKnownColors() {
        XCTAssertEqual(LuxaforColor.red, LuxaforColor(red: 255, green: 0, blue: 0))
        XCTAssertEqual(LuxaforColor.green, LuxaforColor(red: 0, green: 255, blue: 0))
        XCTAssertEqual(LuxaforColor.off, LuxaforColor(red: 0, green: 0, blue: 0))
    }
}
