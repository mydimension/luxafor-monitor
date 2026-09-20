import Foundation
import Combine
import os.log
import LuxaforKit
import MeetingDetectionKit

/// Central orchestration state for the app: owns the current override mode
/// and the most recently detected meeting status, derives the color the
/// light should show, and pushes that color to the `LuxaforDevice`.
///
/// This type intentionally knows nothing about *how* `detectedStatus` is
/// produced — whatever drives detection (in the full app, a
/// `MeetingDetectionKit.DetectionCoordinator`) just calls
/// `updateDetectedStatus(_:readings:)` whenever it has a new fused reading.
/// That keeps `AppState` fully testable and decoupled from the concrete
/// detector/coordinator types.
@MainActor
final class AppState: ObservableObject {
    @Published var overrideMode: OverrideMode = .auto {
        didSet { recomputeColor() }
    }

    @Published private(set) var detectedStatus: MeetingStatus = .unknown {
        didSet { recomputeColor() }
    }

    @Published private(set) var currentColor: LuxaforColor = .off

    @Published private(set) var perAppReadings: [String: DetectorReading] = [:]

    private let device: LuxaforDevice
    private let colorForInMeeting: LuxaforColor
    private let colorForNotInMeeting: LuxaforColor

    private static let log = Logger(subsystem: "com.luxafor-monitor.app", category: "AppState")

    init(
        device: LuxaforDevice,
        colorForInMeeting: LuxaforColor = .red,
        colorForNotInMeeting: LuxaforColor = .green
    ) {
        self.device = device
        self.colorForInMeeting = colorForInMeeting
        self.colorForNotInMeeting = colorForNotInMeeting

        // Establish the initial color (and push it to the device) based on
        // the starting override/detected-status values.
        self.currentColor = Self.computeColor(
            overrideMode: overrideMode,
            detectedStatus: detectedStatus,
            colorForInMeeting: colorForInMeeting,
            colorForNotInMeeting: colorForNotInMeeting
        )

        do {
            try device.connect()
        } catch {
            Self.log.error("Failed to connect to Luxafor device on startup: \(String(describing: error))")
        }

        applyColorToDevice(currentColor)
    }

    /// Called by whatever drives detection (a `DetectionCoordinator`, wired
    /// in at integration time) whenever new fused status / per-app readings
    /// are available.
    func updateDetectedStatus(_ status: MeetingStatus, readings: [String: DetectorReading]) {
        perAppReadings = readings
        detectedStatus = status
    }

    func setOverride(_ mode: OverrideMode) {
        overrideMode = mode
    }

    private func recomputeColor() {
        let newColor = Self.computeColor(
            overrideMode: overrideMode,
            detectedStatus: detectedStatus,
            colorForInMeeting: colorForInMeeting,
            colorForNotInMeeting: colorForNotInMeeting
        )
        guard newColor != currentColor else { return }
        currentColor = newColor
        applyColorToDevice(newColor)
    }

    private func applyColorToDevice(_ color: LuxaforColor) {
        do {
            try device.setColor(color)
        } catch {
            // The device being unplugged/unavailable is an expected,
            // recoverable condition -- log it, but never crash the app.
            Self.log.error("Failed to set Luxafor color: \(String(describing: error))")
        }
    }

    /// Pure function computing the light color for a given override mode
    /// and detected status. Split out from `recomputeColor` so it can be
    /// unit tested without needing a device or a `@MainActor` instance.
    nonisolated static func computeColor(
        overrideMode: OverrideMode,
        detectedStatus: MeetingStatus,
        colorForInMeeting: LuxaforColor,
        colorForNotInMeeting: LuxaforColor
    ) -> LuxaforColor {
        switch overrideMode {
        case .forcedInMeeting:
            return colorForInMeeting
        case .forcedNotInMeeting:
            return colorForNotInMeeting
        case .forcedOff:
            return .off
        case .auto:
            switch detectedStatus {
            case .inMeeting:
                return colorForInMeeting
            case .notInMeeting:
                return colorForNotInMeeting
            case .unknown:
                return .off
            }
        }
    }
}
