import Foundation

/// A manual override the user has set via the menu bar UI, which takes
/// precedence over whatever the fused detector state says.
public enum OverrideMode: Equatable, Sendable {
    /// No manual override: drive the light from fused detector state.
    case auto
    /// Force the "in meeting" (typically red) state regardless of detectors.
    case forcedInMeeting
    /// Force the "not in meeting" (typically green) state regardless of detectors.
    case forcedNotInMeeting
    /// Force the light off regardless of detectors.
    case forcedOff
}
