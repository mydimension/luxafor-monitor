import AppKit
import Foundation

/// Detects active Microsoft Teams meetings.
///
/// Unlike Zoom, Teams has no single stable window title that indicates an
/// active call (it varies by call type, chat title, whether the window is a
/// separate "call" window vs. embedded in the main Teams window, etc.), so
/// this detector instead searches for AX buttons/controls that are only
/// present in an active-call toolbar, such as "Leave", "Hang up", "Mute",
/// and "Turn camera on"/"Turn camera off".
///
/// ⚠️ Heuristic, best-effort, `.medium` confidence: this is exactly the kind
/// of signal that can silently break when Microsoft ships a UI update (e.g.
/// renaming "Leave" to "Leave call", localizing button labels, restructuring
/// the AX tree, etc.). This has **not** been validated against a live Teams
/// install as part of this change — it was written from documented/expected
/// AX button labeling conventions only. Treat this as a first draft that
/// will very likely need adjustment (additional marker strings, possibly
/// per-Teams-version conditionals) once tested against real Teams meetings.
public final class TeamsDetector: MeetingDetector {
    /// Current native Teams client ("Teams 2.x", the Edge WebView2-based
    /// rewrite).
    public static let modernBundleIdentifier = "com.microsoft.teams2"
    /// Legacy (Electron-based) Teams client, kept as a fallback for users
    /// who haven't migrated / still have it installed.
    public static let legacyBundleIdentifier = "com.microsoft.teams"

    /// Button/control labels that indicate an active call toolbar is on
    /// screen somewhere in the app's windows. Deliberately broad, since we
    /// have no single reliable marker the way Zoom's window title provides.
    private static let callControlMarkers = [
        "Leave",
        "Leave meeting",
        "Leave call",
        "Hang up",
        "Mute",
        "Unmute",
        "Turn camera on",
        "Turn camera off",
    ]

    public let detectorName = "Microsoft Teams"

    public init() {}

    public func currentReadings() -> [DetectorReading] {
        guard let bundleIdentifier = runningTeamsBundleIdentifier() else { return [] }

        let windowDetector = AccessibilityWindowDetector(
            bundleIdentifier: bundleIdentifier,
            appDisplayName: "Microsoft Teams",
            rule: WindowSignatureRule(buttonLabelMarkers: Self.callControlMarkers)
        )
        let status = windowDetector.currentStatus()

        return [
            DetectorReading(
                appIdentifier: bundleIdentifier,
                status: status,
                confidence: .medium,
                timestamp: Date()
            )
        ]
    }

    /// Prefers the modern Teams 2.x client if it's running; falls back to
    /// the legacy client; returns `nil` if neither is running.
    private func runningTeamsBundleIdentifier() -> String? {
        let running = NSWorkspace.shared.runningApplications
        if running.contains(where: { $0.bundleIdentifier == Self.modernBundleIdentifier }) {
            return Self.modernBundleIdentifier
        }
        if running.contains(where: { $0.bundleIdentifier == Self.legacyBundleIdentifier }) {
            return Self.legacyBundleIdentifier
        }
        return nil
    }
}
