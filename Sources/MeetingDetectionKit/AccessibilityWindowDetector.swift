import AppKit
import ApplicationServices
import Foundation

/// Declaratively describes what an "in meeting" window looks like for a
/// given app, so that app-specific detectors (`ZoomDetector`, `TeamsDetector`,
/// ...) can be built by composing rules rather than writing bespoke AX
/// tree-walking code each time.
///
/// A window is considered a match if `titleRegex` matches the window's
/// title, OR the window's AX subtree contains a button whose title matches
/// one of `buttonLabelMarkers` (case-insensitive substring match), OR both,
/// depending on which fields are populated. At least one of the two should
/// normally be set; if both are `nil`/empty the rule matches no windows.
public struct WindowSignatureRule: Sendable {
    /// Matched against the window's `kAXTitleAttribute`. `nil` means "don't
    /// check the title".
    public var titleRegex: NSRegularExpression?

    /// Button/label titles (e.g. "Leave", "Mute", "Turn camera on") that, if
    /// found anywhere in the window's AX subtree, indicate an active meeting
    /// UI. Matching is case-insensitive substring matching against AX
    /// elements' `kAXTitleAttribute` (checked regardless of role, since
    /// different apps expose meeting controls as buttons, menu items, or
    /// static text). Empty array means "don't search for buttons".
    public var buttonLabelMarkers: [String]

    public init(titleRegex: NSRegularExpression? = nil, buttonLabelMarkers: [String] = []) {
        self.titleRegex = titleRegex
        self.buttonLabelMarkers = buttonLabelMarkers
    }

    /// Convenience initializer for an exact (case-sensitive) window title
    /// match, e.g. Zoom's long-stable `"Zoom Meeting"` window title.
    public init(exactTitle: String, buttonLabelMarkers: [String] = []) {
        let escaped = NSRegularExpression.escapedPattern(for: exactTitle)
        self.titleRegex = try? NSRegularExpression(pattern: "^\(escaped)$")
        self.buttonLabelMarkers = buttonLabelMarkers
    }
}

/// Reusable Accessibility-API-based engine for detecting whether a given
/// application currently has a window that matches a `WindowSignatureRule`.
///
/// Deliberately reads window titles via `AXUIElementCopyAttributeValue`
/// (`kAXTitleAttribute`) rather than `CGWindowListCopyWindowInfo`, so that
/// the host app only needs to request **Accessibility** permission, not the
/// much more sensitive **Screen Recording** permission, in order to read the
/// window titles of other applications.
///
/// This class is intentionally *not* a `MeetingDetector` itself — it has no
/// opinion on confidence or on what bundle identifier to report under.
/// App-specific detectors (e.g. `ZoomDetector`) wrap it with a
/// `MeetingDetector` conformance and their own confidence level.
public final class AccessibilityWindowDetector {
    /// Maximum depth to recurse into an AX subtree when searching for
    /// button-label markers, to bound worst-case traversal time against
    /// deep/unusual accessibility trees.
    private let maxSearchDepth = 6

    /// Maximum total AX nodes to visit while searching a single window's
    /// subtree for button-label markers, as a second guard against
    /// pathological (e.g. very wide) trees causing a hang.
    private let maxNodesVisited = 500

    public let bundleIdentifier: String
    public let appDisplayName: String
    public let rule: WindowSignatureRule

    public init(bundleIdentifier: String, appDisplayName: String, rule: WindowSignatureRule) {
        self.bundleIdentifier = bundleIdentifier
        self.appDisplayName = appDisplayName
        self.rule = rule
    }

    /// Returns `.unknown` if Accessibility permission has not been granted
    /// to this process, or if the target app isn't currently running.
    /// Otherwise returns `.inMeeting` if any window of the target app
    /// matches `rule`, else `.notInMeeting`.
    public func currentStatus() -> MeetingStatus {
        guard AXIsProcessTrusted() else { return .unknown }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            return .unknown
        }

        let pid = runningApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
            // App is running but exposes no windows via AX (could be
            // launching, or could be denying AX access some other way).
            return .notInMeeting
        }

        for window in windows {
            if matches(window: window, rule: rule) {
                return .inMeeting
            }
        }
        return .notInMeeting
    }

    // MARK: - Matching

    private func matches(window: AXUIElement, rule: WindowSignatureRule) -> Bool {
        if let titleRegex = rule.titleRegex {
            if let title = copyAttribute(window, kAXTitleAttribute) as? String {
                let range = NSRange(title.startIndex..<title.endIndex, in: title)
                if titleRegex.firstMatch(in: title, options: [], range: range) != nil {
                    return true
                }
            }
        }

        if !rule.buttonLabelMarkers.isEmpty {
            var nodesVisited = 0
            if subtreeContainsMarker(window, markers: rule.buttonLabelMarkers, depth: 0, nodesVisited: &nodesVisited) {
                return true
            }
        }

        return false
    }

    /// Bounded-depth, bounded-node-count recursive search of an AX subtree
    /// for any element whose title contains one of `markers` as a
    /// case-insensitive substring.
    private func subtreeContainsMarker(
        _ element: AXUIElement,
        markers: [String],
        depth: Int,
        nodesVisited: inout Int
    ) -> Bool {
        guard depth <= maxSearchDepth, nodesVisited < maxNodesVisited else { return false }
        nodesVisited += 1

        if let title = copyAttribute(element, kAXTitleAttribute) as? String, !title.isEmpty {
            for marker in markers {
                if title.range(of: marker, options: .caseInsensitive) != nil {
                    return true
                }
            }
        }

        guard let children = copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else {
            return false
        }

        for child in children {
            if nodesVisited >= maxNodesVisited { return false }
            if subtreeContainsMarker(child, markers: markers, depth: depth + 1, nodesVisited: &nodesVisited) {
                return true
            }
        }
        return false
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }
}
