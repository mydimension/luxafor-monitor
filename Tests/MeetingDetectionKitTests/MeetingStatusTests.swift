import XCTest
@testable import MeetingDetectionKit

final class MeetingStatusTests: XCTestCase {
    func testDetectorReadingCarriesFields() {
        let reading = DetectorReading(
            appIdentifier: "us.zoom.xos",
            status: .inMeeting,
            confidence: .high
        )
        XCTAssertEqual(reading.appIdentifier, "us.zoom.xos")
        XCTAssertEqual(reading.status, .inMeeting)
        XCTAssertEqual(reading.confidence, .high)
    }

    func testConfidenceOrdering() {
        XCTAssertLessThan(DetectorConfidence.low, DetectorConfidence.medium)
        XCTAssertLessThan(DetectorConfidence.medium, DetectorConfidence.high)
    }
}
