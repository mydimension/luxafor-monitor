import SwiftUI
import LuxaforKit
import MeetingDetectionKit

/// Booleans + actions the menu bar view needs to show a permissions nag
/// banner, without depending on the concrete `PermissionsManager` type.
///
/// At integration time this is populated from a live `PermissionsManager`'s
/// `@Published` properties and methods.
struct PermissionsStatus {
    var accessibilityGranted: Bool
    var cameraGranted: Bool
    var microphoneGranted: Bool

    var requestAccessibilityPermission: () -> Void
    var requestMediaPermissions: () -> Void
    var openAccessibilitySettings: () -> Void

    var allGranted: Bool {
        accessibilityGranted && cameraGranted && microphoneGranted
    }

    static let allGrantedPlaceholder = PermissionsStatus(
        accessibilityGranted: true,
        cameraGranted: true,
        microphoneGranted: true,
        requestAccessibilityPermission: {},
        requestMediaPermissions: {},
        openAccessibilitySettings: {}
    )
}

/// The `MenuBarExtra` dropdown content. A plain view: it reads state from
/// `AppState` (which is self-contained) and takes permission status /
/// actions as plain data, so it never needs to know about
/// `PermissionsManager`.
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var permissions: PermissionsStatus
    var openPreferences: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader

            if !appState.perAppReadings.isEmpty {
                Divider()
                perAppList
            }

            Divider()
            overrideControls

            if !permissions.allGranted {
                Divider()
                permissionsBanner
            }

            Divider()

            Button("Preferences…") {
                openPreferences()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
        .frame(minWidth: 280)
    }

    private var statusHeader: some View {
        HStack {
            Circle()
                .fill(appState.currentColor.swiftUIColor)
                .frame(width: 12, height: 12)
            Text(statusText)
                .font(.headline)
            Spacer()
        }
    }

    private var statusText: String {
        switch appState.detectedStatus {
        case .inMeeting: return "In a meeting"
        case .notInMeeting: return "Not in a meeting"
        case .unknown: return "Unknown"
        }
    }

    private var perAppList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Detected apps")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(appState.perAppReadings.keys.sorted(), id: \.self) { key in
                if let reading = appState.perAppReadings[key] {
                    HStack {
                        Text(displayName(for: reading.appIdentifier))
                        Spacer()
                        Text(shortStatus(reading.status))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var overrideControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Light control")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { appState.overrideMode },
                set: { appState.setOverride($0) }
            )) {
                Text("Auto").tag(OverrideMode.auto)
                Text("Force Red").tag(OverrideMode.forcedInMeeting)
                Text("Force Green").tag(OverrideMode.forcedNotInMeeting)
                Text("Force Off").tag(OverrideMode.forcedOff)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if appState.overrideMode != .auto {
                Text("Manual override active — tap Auto to resume automatic detection.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var permissionsBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Permissions needed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            if !permissions.accessibilityGranted {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility access lets Luxafor Monitor read Teams/Zoom window titles to detect meetings.")
                        .font(.caption)
                    Button("Grant Accessibility Access…") {
                        permissions.requestAccessibilityPermission()
                    }
                    .font(.caption)
                }
            }

            if !permissions.cameraGranted || !permissions.microphoneGranted {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Camera/Microphone access lets Luxafor Monitor observe whether they're in use as a meeting signal (nothing is recorded).")
                        .font(.caption)
                    Button("Grant Camera/Microphone Access…") {
                        permissions.requestMediaPermissions()
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func displayName(for appIdentifier: String) -> String {
        switch appIdentifier.lowercased() {
        case let id where id.contains("zoom"):
            return "Zoom"
        case let id where id.contains("teams"):
            return "Microsoft Teams"
        default:
            return appIdentifier
        }
    }

    private func shortStatus(_ status: MeetingStatus) -> String {
        switch status {
        case .inMeeting: return "In meeting"
        case .notInMeeting: return "Not in meeting"
        case .unknown: return "Unknown"
        }
    }
}
