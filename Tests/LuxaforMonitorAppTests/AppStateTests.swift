import XCTest
@testable import LuxaforMonitorApp
import LuxaforKit
import MeetingDetectionKit

/// Tests for `AppState.computeColor`, the pure function driving what color
/// the light should show for a given override mode / detected status
/// combination. This is the important piece of logic in this module; the
/// rest is SwiftUI view plumbing.
final class AppStateTests: XCTestCase {
    private let inMeetingColor = LuxaforColor.red
    private let notInMeetingColor = LuxaforColor.green

    func testAutoModeFollowsDetectedStatus() {
        XCTAssertEqual(
            AppState.computeColor(
                overrideMode: .auto,
                detectedStatus: .inMeeting,
                colorForInMeeting: inMeetingColor,
                colorForNotInMeeting: notInMeetingColor
            ),
            inMeetingColor
        )
        XCTAssertEqual(
            AppState.computeColor(
                overrideMode: .auto,
                detectedStatus: .notInMeeting,
                colorForInMeeting: inMeetingColor,
                colorForNotInMeeting: notInMeetingColor
            ),
            notInMeetingColor
        )
        XCTAssertEqual(
            AppState.computeColor(
                overrideMode: .auto,
                detectedStatus: .unknown,
                colorForInMeeting: inMeetingColor,
                colorForNotInMeeting: notInMeetingColor
            ),
            .off
        )
    }

    func testForcedInMeetingIgnoresDetectedStatus() {
        for status: MeetingStatus in [.inMeeting, .notInMeeting, .unknown] {
            XCTAssertEqual(
                AppState.computeColor(
                    overrideMode: .forcedInMeeting,
                    detectedStatus: status,
                    colorForInMeeting: inMeetingColor,
                    colorForNotInMeeting: notInMeetingColor
                ),
                inMeetingColor
            )
        }
    }

    func testForcedNotInMeetingIgnoresDetectedStatus() {
        for status: MeetingStatus in [.inMeeting, .notInMeeting, .unknown] {
            XCTAssertEqual(
                AppState.computeColor(
                    overrideMode: .forcedNotInMeeting,
                    detectedStatus: status,
                    colorForInMeeting: inMeetingColor,
                    colorForNotInMeeting: notInMeetingColor
                ),
                notInMeetingColor
            )
        }
    }

    func testForcedOffIgnoresDetectedStatus() {
        for status: MeetingStatus in [.inMeeting, .notInMeeting, .unknown] {
            XCTAssertEqual(
                AppState.computeColor(
                    overrideMode: .forcedOff,
                    detectedStatus: status,
                    colorForInMeeting: inMeetingColor,
                    colorForNotInMeeting: notInMeetingColor
                ),
                .off
            )
        }
    }

    func testCustomColorsAreRespected() {
        let customInMeeting = LuxaforColor(red: 10, green: 20, blue: 30)
        let customNotInMeeting = LuxaforColor(red: 40, green: 50, blue: 60)
        XCTAssertEqual(
            AppState.computeColor(
                overrideMode: .auto,
                detectedStatus: .inMeeting,
                colorForInMeeting: customInMeeting,
                colorForNotInMeeting: customNotInMeeting
            ),
            customInMeeting
        )
    }

    @MainActor
    func testUpdateDetectedStatusRecomputesCurrentColorInAutoMode() {
        let device = RecordingLuxaforDevice()
        let appState = AppState(device: device)

        appState.updateDetectedStatus(.inMeeting, readings: [:])
        XCTAssertEqual(appState.currentColor, .red)
        XCTAssertEqual(appState.detectedStatus, .inMeeting)

        appState.updateDetectedStatus(.notInMeeting, readings: [:])
        XCTAssertEqual(appState.currentColor, .green)
    }

    @MainActor
    func testOverrideTakesPrecedenceOverDetectedStatus() {
        let device = RecordingLuxaforDevice()
        let appState = AppState(device: device)

        appState.updateDetectedStatus(.inMeeting, readings: [:])
        XCTAssertEqual(appState.currentColor, .red)

        appState.setOverride(.forcedOff)
        XCTAssertEqual(appState.currentColor, .off)

        appState.setOverride(.auto)
        XCTAssertEqual(appState.currentColor, .red)
    }

    @MainActor
    func testDeviceErrorsDoNotCrashAppState() {
        let device = RecordingLuxaforDevice()
        device.shouldThrowOnSetColor = true
        let appState = AppState(device: device)

        // Should not throw/crash even though the device fails every write.
        appState.updateDetectedStatus(.inMeeting, readings: [:])
        XCTAssertEqual(appState.currentColor, .red)
    }
}

/// Simple in-memory `LuxaforDevice` used to verify `AppState` pushes color
/// changes to the device without needing real hardware.
private final class RecordingLuxaforDevice: LuxaforDevice {
    private(set) var isConnected: Bool = false
    private(set) var colorsSet: [LuxaforColor] = []
    var shouldThrowOnSetColor = false

    func connect() throws {
        isConnected = true
    }

    func setColor(_ color: LuxaforColor) throws {
        if shouldThrowOnSetColor {
            throw LuxaforDeviceError.notConnected
        }
        colorsSet.append(color)
    }

    func turnOff() throws {
        try setColor(.off)
    }
}
