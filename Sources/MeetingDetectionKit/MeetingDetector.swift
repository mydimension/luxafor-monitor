import Foundation

/// How much weight a `DetectionCoordinator` should give a reading when
/// fusing signals from multiple detectors.
public enum DetectorConfidence: Int, Comparable, Sendable {
    /// System-wide signals that can't be attributed to a specific app
    /// (e.g. "some process is using the microphone").
    case low = 0
    /// Attributable to a specific app, but based on a heuristic that could
    /// drift as the app's UI changes.
    case medium = 1
    /// A precise, well-known marker for that app being in a call.
    case high = 2

    public static func < (lhs: DetectorConfidence, rhs: DetectorConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single detector's opinion about one app's meeting status at a point in time.
public struct DetectorReading: Equatable, Sendable {
    /// Stable identifier for the app this reading is about, e.g. a bundle
    /// identifier like "com.microsoft.teams2" or "us.zoom.xos".
    public var appIdentifier: String
    public var status: MeetingStatus
    public var confidence: DetectorConfidence
    public var timestamp: Date

    public init(
        appIdentifier: String,
        status: MeetingStatus,
        confidence: DetectorConfidence,
        timestamp: Date = Date()
    ) {
        self.appIdentifier = appIdentifier
        self.status = status
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

/// A pluggable strategy for detecting meeting status of one or more apps
/// from local, unauthenticated OS-level signals.
///
/// This is the extensibility point for adding support for new meeting apps:
/// implement this protocol (optionally reusing helpers like an AX-based
/// window scanner) and register the instance with a `DetectionCoordinator`.
public protocol MeetingDetector: AnyObject {
    /// Human-readable name for logging/preferences UI, e.g. "Zoom".
    var detectorName: String { get }

    /// Returns the detector's current best-effort readings. May return an
    /// empty array if the detector currently has nothing to report (e.g. the
    /// app it watches isn't running).
    func currentReadings() -> [DetectorReading]
}
