import SwiftUI
import AppKit
import LuxaforKit
import MeetingDetectionKit

/// Bundle identifiers of meeting apps `MediaUsageDetector` should attribute
/// mic/camera usage to. Kept in sync with the apps `ZoomDetector`/
/// `TeamsDetector` watch.
private let watchedMeetingAppBundleIdentifiers = [
    "us.zoom.xos",
    "com.microsoft.teams2",
    "com.microsoft.teams",
]

// MARK: - App entry point

@main
struct LuxaforMonitorApp: App {
    @StateObject private var appState: AppState
    @StateObject private var permissionsManager: PermissionsManager
    @StateObject private var detectionCoordinator: DetectionCoordinator

    // MARK: Preferences state
    //
    // TODO(follow-up): persist these (e.g. via `@AppStorage` or a small
    // dedicated settings store), and make toggling a detector or the poll
    // interval in Preferences live-reconfigure `detectionCoordinator`
    // instead of only taking effect on next launch.
    @State private var detectorEnabled: [String: Bool] = [
        "Zoom": true,
        "Microsoft Teams": true,
        "Media Usage": true,
    ]
    @State private var pollInterval: Double = 3.0
    @State private var colorForInMeeting: LuxaforColor = .red
    @State private var colorForNotInMeeting: LuxaforColor = .green

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let device = LuxaforUSBDevice()
        let state = AppState(
            device: device,
            colorForInMeeting: .red,
            colorForNotInMeeting: .green
        )

        let coordinator = DetectionCoordinator(
            detectors: [
                ZoomDetector(),
                TeamsDetector(),
                MediaUsageDetector(relevantBundleIdentifiers: watchedMeetingAppBundleIdentifiers),
            ],
            pollInterval: 3.0
        )
        state.observeDetectionCoordinator(coordinator)
        coordinator.start()

        _appState = StateObject(wrappedValue: state)
        _detectionCoordinator = StateObject(wrappedValue: coordinator)
        _permissionsManager = StateObject(wrappedValue: PermissionsManager())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                permissions: permissionsStatus,
                openPreferences: openPreferencesWindow
            )
            .onAppear { permissionsManager.refreshStatus() }
        } label: {
            Image(systemName: "flag.fill")
                .foregroundStyle(appState.currentColor.swiftUIColor)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to Luxafor Monitor", id: "onboarding") {
            OnboardingWindowContent(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                accessibilityGranted: permissionsManager.accessibilityGranted,
                mediaGranted: permissionsManager.cameraGranted && permissionsManager.microphoneGranted,
                requestAccessibilityPermission: permissionsStatus.requestAccessibilityPermission,
                requestMediaPermissions: permissionsStatus.requestMediaPermissions,
                openAccessibilitySettings: permissionsStatus.openAccessibilitySettings
            )
            .onAppear { permissionsManager.refreshStatus() }
        }
        .windowResizability(.contentSize)

        Settings {
            PreferencesView(
                detectorEnabled: $detectorEnabled,
                pollInterval: $pollInterval,
                colorForInMeeting: $colorForInMeeting,
                colorForNotInMeeting: $colorForNotInMeeting
            )
        }
    }

    private var permissionsStatus: PermissionsStatus {
        PermissionsStatus(
            accessibilityGranted: permissionsManager.accessibilityGranted,
            cameraGranted: permissionsManager.cameraGranted,
            microphoneGranted: permissionsManager.microphoneGranted,
            requestAccessibilityPermission: {
                permissionsManager.requestAccessibilityPermission()
            },
            requestMediaPermissions: {
                Task { await permissionsManager.requestMediaPermissions() }
            },
            openAccessibilitySettings: {
                permissionsManager.openAccessibilitySettings()
            }
        )
    }

    private func openPreferencesWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

/// Wraps `OnboardingView` for use in a `Window` scene: shows the real
/// onboarding content until it's completed, then closes its own window so
/// it doesn't linger as an empty window on subsequent launches.
private struct OnboardingWindowContent: View {
    @Binding var hasCompletedOnboarding: Bool
    var accessibilityGranted: Bool
    var mediaGranted: Bool
    var requestAccessibilityPermission: () -> Void
    var requestMediaPermissions: () -> Void
    var openAccessibilitySettings: () -> Void

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                Color.clear
            } else {
                OnboardingView(
                    accessibilityGranted: accessibilityGranted,
                    mediaGranted: mediaGranted,
                    requestAccessibilityPermission: requestAccessibilityPermission,
                    requestMediaPermissions: requestMediaPermissions,
                    openAccessibilitySettings: openAccessibilitySettings,
                    onFinish: { hasCompletedOnboarding = true }
                )
            }
        }
        .onChange(of: hasCompletedOnboarding) { completed in
            if completed {
                NSApp.keyWindow?.close()
            }
        }
        .onAppear {
            if hasCompletedOnboarding {
                NSApp.keyWindow?.close()
            }
        }
    }
}
