import XCTest
@testable import LuxaforKit

final class LuxaforProtocolTests: XCTestCase {
    func testRedReport() {
        let report = LuxaforProtocol.staticColorReport(for: .red)
        XCTAssertEqual(report, [0x00, 0x01, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    func testGreenReport() {
        let report = LuxaforProtocol.staticColorReport(for: .green)
        XCTAssertEqual(report, [0x00, 0x01, 0xFF, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00])
    }

    func testOffReport() {
        let report = LuxaforProtocol.staticColorReport(for: .off)
        XCTAssertEqual(report, [0x00, 0x01, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    func testCustomColorReport() {
        let color = LuxaforColor(red: 12, green: 200, blue: 77)
        let report = LuxaforProtocol.staticColorReport(for: color)
        XCTAssertEqual(report, [0x00, 0x01, 0xFF, 12, 200, 77, 0x00, 0x00, 0x00])
    }

    func testCustomLEDTargetIsEncodedInByteTwo() {
        let report = LuxaforProtocol.staticColorReport(for: .red, ledTarget: 0x01)
        XCTAssertEqual(report, [0x00, 0x01, 0x01, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    func testReportHasFixedLength() {
        XCTAssertEqual(LuxaforProtocol.staticColorReport(for: .red).count, LuxaforProtocol.reportLength)
    }
}
