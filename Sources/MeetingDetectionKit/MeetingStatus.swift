import Foundation

/// Whether a given app appears to be in an active meeting/call.
public enum MeetingStatus: Equatable, Sendable {
    case inMeeting
    case notInMeeting
    /// The detector couldn't determine a status (e.g. app not running,
    /// or a required permission hasn't been granted yet).
    case unknown
}
