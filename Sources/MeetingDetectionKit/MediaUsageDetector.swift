import AppKit
import AVFoundation
import Foundation

/// Detects meeting-like activity by watching whether *any* application on the
/// system is currently using the camera and/or microphone.
///
/// This is a "system-wide" signal: macOS only tells us that *some* process is
/// using a capture device, not which one. `MediaUsageDetector` narrows this
/// down heuristically by only reporting `.inMeeting` for bundle identifiers
/// that are (a) in a caller-supplied allow-list of "relevant" apps and (b)
/// currently running, at the moment media is in use. This can never be more
/// than `.low` confidence, since a match is correlational, not causal — e.g.
/// if both Zoom and QuickTime are running and QuickTime is recording audio,
/// this detector cannot tell the two apart and will (incorrectly) also flag
/// Zoom as "in a meeting".
///
/// ## Privacy / permissions disclosure
///
/// `AVCaptureDevice.isInUseByAnotherApplication` only reflects the real,
/// live state of the camera/microphone if **this host app** has been granted
/// camera and microphone permission by the user (via TCC), even though this
/// app never actually opens a capture session or records/transmits any
/// audio or video itself. If permission has not been granted, the property
/// generally reads back `false` regardless of actual device usage, which
/// would make this detector silently useless (always reporting
/// `.notInMeeting`) rather than failing loudly.
///
/// This is a notable, disclosure-worthy detail for an open-source project:
/// asking a user to grant camera/microphone access to a "menu bar light
/// status" app is a legitimate privacy question, even though the app only
/// ever reads a boolean "is this device busy" flag and never captures any
/// media. The permission prompt/request flow is intentionally handled
/// elsewhere (see `PermissionsManager`), and should be clearly explained to
/// users in product-facing copy (e.g. a permissions onboarding screen).
public final class MediaUsageDetector: MeetingDetector {
    public let detectorName = "Media Usage"

    private let relevantBundleIdentifiers: [String]

    /// - Parameter relevantBundleIdentifiers: bundle identifiers of apps this
    ///   detector is allowed to attribute camera/microphone usage to (e.g.
    ///   `["us.zoom.xos", "com.microsoft.teams2"]`). Any other running app is
    ///   ignored entirely by this detector.
    public init(relevantBundleIdentifiers: [String]) {
        self.relevantBundleIdentifiers = relevantBundleIdentifiers
    }

    public func currentReadings() -> [DetectorReading] {
        let mediaInUse = isCameraInUse() || isMicrophoneInUse()
        let now = Date()
        let running = NSWorkspace.shared.runningApplications

        var readings: [DetectorReading] = []
        for bundleIdentifier in relevantBundleIdentifiers {
            let isRunning = running.contains { $0.bundleIdentifier == bundleIdentifier }
            guard isRunning else { continue }

            let status: MeetingStatus = mediaInUse ? .inMeeting : .notInMeeting
            readings.append(
                DetectorReading(
                    appIdentifier: bundleIdentifier,
                    status: status,
                    confidence: .low,
                    timestamp: now
                )
            )
        }
        return readings
    }

    private func isCameraInUse() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.isInUseByAnotherApplication
    }

    private func isMicrophoneInUse() -> Bool {
        guard let device = AVCaptureDevice.default(for: .audio) else { return false }
        return device.isInUseByAnotherApplication
    }
}
