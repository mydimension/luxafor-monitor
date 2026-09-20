import XCTest
@testable import MeetingDetectionKit

/// A fake detector whose `currentReadings()` output can be swapped out by
/// the test between calls to `DetectionCoordinator.refreshNow()`, so tests
/// can drive deterministic poll-by-poll scenarios without any real AX/AV
/// calls.
private final class FakeDetector: MeetingDetector {
    let detectorName: String
    var readings: [DetectorReading]

    init(detectorName: String, readings: [DetectorReading] = []) {
        self.detectorName = detectorName
        self.readings = readings
    }

    func currentReadings() -> [DetectorReading] {
        readings
    }
}

@MainActor
final class DetectionCoordinatorTests: XCTestCase {
    private func reading(
        _ app: String,
        _ status: MeetingStatus,
        _ confidence: DetectorConfidence = .high
    ) -> DetectorReading {
        DetectorReading(appIdentifier: app, status: status, confidence: confidence)
    }

    func testSingleDetectorInMeetingBecomesStableAfterRequiredPolls() {
        let detector = FakeDetector(detectorName: "fake", readings: [reading("app.a", .inMeeting)])
        let coordinator = DetectionCoordinator(detectors: [detector], requiredStableReadings: 2)

        coordinator.refreshNow()
        XCTAssertEqual(coordinator.fusedStatus, .unknown, "should not flip on the very first poll")

        coordinator.refreshNow()
        XCTAssertEqual(coordinator.fusedStatus, .inMeeting, "should flip after 2 consecutive matching polls")
    }

    func testAnyDetectorInMeetingWinsOverAnotherNotInMeeting() {
        let inMeetingDetector = FakeDetector(detectorName: "a", readings: [reading("app.a", .inMeeting)])
        let notInMeetingDetector = FakeDetector(detectorName: "b", readings: [reading("app.b", .notInMeeting)])
        let coordinator = DetectionCoordinator(
            detectors: [inMeetingDetector, notInMeetingDetector],
            requiredStableReadings: 2
        )

        coordinator.refreshNow()
        coordinator.refreshNow()

        XCTAssertEqual(coordinator.fusedStatus, .inMeeting)
        XCTAssertEqual(coordinator.latestReadings["app.a"]?.status, .inMeeting)
        XCTAssertEqual(coordinator.latestReadings["app.b"]?.status, .notInMeeting)
    }

    func testTransientFlipIsDebouncedAway() {
        let detector = FakeDetector(detectorName: "fake", readings: [reading("app.a", .notInMeeting)])
        let coordinator = DetectionCoordinator(detectors: [detector], requiredStableReadings: 2)

        // Establish a stable "not in meeting" baseline.
        coordinator.refreshNow()
        coordinator.refreshNow()
        XCTAssertEqual(coordinator.fusedStatus, .notInMeeting)

        // Single-poll blip to "in meeting"...
        detector.readings = [reading("app.a", .inMeeting)]
        coordinator.refreshNow()
        XCTAssertEqual(coordinator.fusedStatus, .notInMeeting, "a single noisy poll must not move the fused status")

        // ...then immediately back to "not in meeting".
        detector.readings = [reading("app.a", .notInMeeting)]
        coordinator.refreshNow()
        XCTAssertEqual(
            coordinator.fusedStatus,
            .notInMeeting,
            "status should remain at its prior stable value throughout the blip"
        )
    }

    func testNoDetectorsYieldsUnknown() {
        let coordinator = DetectionCoordinator(detectors: [], requiredStableReadings: 2)

        coordinator.refreshNow()
        coordinator.refreshNow()
        coordinator.refreshNow()

        XCTAssertEqual(coordinator.fusedStatus, .unknown)
        XCTAssertTrue(coordinator.latestReadings.isEmpty)
    }

    func testDetectorsReportingNothingYieldsUnknown() {
        let emptyDetector = FakeDetector(detectorName: "empty", readings: [])
        let coordinator = DetectionCoordinator(detectors: [emptyDetector], requiredStableReadings: 2)

        coordinator.refreshNow()
        coordinator.refreshNow()

        XCTAssertEqual(coordinator.fusedStatus, .unknown)
    }

    func testConflictingConfidenceForSameAppPrefersHigherConfidence() {
        let lowConfidenceDetector = FakeDetector(
            detectorName: "low",
            readings: [reading("app.a", .notInMeeting, .low)]
        )
        let highConfidenceDetector = FakeDetector(
            detectorName: "high",
            readings: [reading("app.a", .inMeeting, .high)]
        )
        let coordinator = DetectionCoordinator(
            detectors: [lowConfidenceDetector, highConfidenceDetector],
            requiredStableReadings: 1
        )

        coordinator.refreshNow()

        XCTAssertEqual(coordinator.latestReadings["app.a"]?.confidence, .high)
        XCTAssertEqual(coordinator.latestReadings["app.a"]?.status, .inMeeting)

        // Order reversed: the higher-confidence reading should still win
        // regardless of which detector reported it first.
        let coordinator2 = DetectionCoordinator(
            detectors: [highConfidenceDetector, lowConfidenceDetector],
            requiredStableReadings: 1
        )
        coordinator2.refreshNow()
        XCTAssertEqual(coordinator2.latestReadings["app.a"]?.confidence, .high)
    }

    func testUnknownReadingLosesToNonUnknownRegardlessOfConfidence() {
        let unknownHighConfidence = FakeDetector(
            detectorName: "unknown",
            readings: [reading("app.a", .unknown, .high)]
        )
        let knownLowConfidence = FakeDetector(
            detectorName: "known",
            readings: [reading("app.a", .notInMeeting, .low)]
        )
        let coordinator = DetectionCoordinator(
            detectors: [unknownHighConfidence, knownLowConfidence],
            requiredStableReadings: 1
        )

        coordinator.refreshNow()

        XCTAssertEqual(coordinator.latestReadings["app.a"]?.status, .notInMeeting)
    }

    func testRequiredStableReadingsOfOneUpdatesImmediately() {
        let detector = FakeDetector(detectorName: "fake", readings: [reading("app.a", .inMeeting)])
        let coordinator = DetectionCoordinator(detectors: [detector], requiredStableReadings: 1)

        coordinator.refreshNow()

        XCTAssertEqual(coordinator.fusedStatus, .inMeeting)
    }
}
