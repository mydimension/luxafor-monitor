import AppKit
import Foundation

/// Detects active Zoom meetings by looking for a window titled exactly
/// "Zoom Meeting". This has been a long-standing, stable behavior of the
/// Zoom desktop client on macOS: the in-call window's title is always
/// literally "Zoom Meeting" regardless of the actual meeting topic,
/// participants, or language settings, which makes it an unusually reliable
/// (`.high` confidence) signal compared to typical UI heuristics.
public final class ZoomDetector: MeetingDetector {
    /// Current native Zoom client bundle identifier.
    public static let bundleIdentifier = "us.zoom.xos"

    public let detectorName = "Zoom"

    private let windowDetector: AccessibilityWindowDetector

    public init() {
        windowDetector = AccessibilityWindowDetector(
            bundleIdentifier: Self.bundleIdentifier,
            appDisplayName: "Zoom",
            rule: WindowSignatureRule(exactTitle: "Zoom Meeting")
        )
    }

    public func currentReadings() -> [DetectorReading] {
        let isRunning = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.bundleIdentifier)
            .isEmpty == false
        guard isRunning else { return [] }

        let status = windowDetector.currentStatus()
        // If Accessibility isn't authorized, `currentStatus()` returns
        // `.unknown` even though Zoom is running; we still report it (at
        // low confidence would be misleading, so we keep `.high` since the
        // *rule* itself is high-confidence — the caller can see `.unknown`
        // and prompt for Accessibility permission separately).
        return [
            DetectorReading(
                appIdentifier: Self.bundleIdentifier,
                status: status,
                confidence: .high,
                timestamp: Date()
            )
        ]
    }
}
