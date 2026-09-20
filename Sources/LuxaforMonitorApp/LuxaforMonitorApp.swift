import SwiftUI
import AppKit
import LuxaforKit
import MeetingDetectionKit

// MARK: - No-op device placeholder

/// Local no-op stand-in for a real `LuxaforDevice`, used only so this
/// module has something concrete to construct `AppState` with while the
/// real USB HID driver is being built in a separate worktree.
///
/// TODO(integration): replace with `LuxaforKit.LuxaforUSBDevice()`.
final class NoOpLuxaforDevice: LuxaforDevice {
    private(set) var isConnected: Bool = false

    func connect() throws {
        isConnected = true
    }

    func setColor(_ color: LuxaforColor) throws {
        // Intentionally a no-op: no real hardware backs this placeholder.
    }

    func turnOff() throws {
        try setColor(.off)
    }
}

// MARK: - App entry point

@main
struct LuxaforMonitorApp: App {
    @StateObject private var appState: AppState

    // MARK: Preferences state
    //
    // TODO(integration): persist these (e.g. via `@AppStorage` or a small
    // dedicated settings store) instead of in-memory `@State`, and use them
    // to configure the real detection stack -- see the TODO block below.
    @State private var detectorEnabled: [String: Bool] = [
        "Zoom": true,
        "Microsoft Teams": true,
        "Media Usage": true,
    ]
    @State private var pollInterval: Double = 3.0
    @State private var colorForInMeeting: LuxaforColor = .red
    @State private var colorForNotInMeeting: LuxaforColor = .green

    // MARK: Permissions placeholder state
    //
    // TODO(integration): replace this block with a real
    // `MeetingDetectionKit.PermissionsManager`:
    //
    //   @StateObject private var permissionsManager = PermissionsManager()
    //
    // and thread `permissionsManager.accessibilityGranted`,
    // `.cameraGranted`, `.microphoneGranted`,
    // `.requestAccessibilityPermission()`, `.requestMediaPermissions()`
    // (async), and `.openAccessibilitySettings()` through to
    // `MenuBarView`/`OnboardingView` in place of the placeholders below.
    // Also call `permissionsManager.refreshStatus()` on scene activation.
    @State private var accessibilityGranted = true
    @State private var cameraGranted = true
    @State private var microphoneGranted = true

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        // TODO(integration): construct AppState with the real device and
        // start a real detection loop, e.g.:
        //
        //   let device = LuxaforUSBDevice()
        //   let appState = AppState(device: device)
        //   let coordinator = DetectionCoordinator(
        //       detectors: [ZoomDetector(), TeamsDetector(), MediaUsageDetector(relevantBundleIdentifiers: [...])],
        //       pollInterval: pollInterval
        //   )
        //   coordinator.$fusedStatus
        //       .combineLatest(coordinator.$latestReadings)
        //       .sink { status, readings in appState.updateDetectedStatus(status, readings: readings) }
        //       .store(in: &cancellables)
        //   coordinator.start()
        //
        // (Respecting `detectorEnabled` when building the `detectors` array,
        // and keeping a reference to `coordinator` / the Combine
        // subscription alive for the app's lifetime.)
        _appState = StateObject(wrappedValue: AppState(
            device: NoOpLuxaforDevice(),
            colorForInMeeting: .red,
            colorForNotInMeeting: .green
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                permissions: permissionsStatus,
                openPreferences: openPreferencesWindow
            )
        } label: {
            Image(systemName: "flag.fill")
                .foregroundStyle(appState.currentColor.swiftUIColor)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to Luxafor Monitor", id: "onboarding") {
            OnboardingWindowContent(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                accessibilityGranted: accessibilityGranted,
                mediaGranted: cameraGranted && microphoneGranted,
                requestAccessibilityPermission: permissionsStatus.requestAccessibilityPermission,
                requestMediaPermissions: permissionsStatus.requestMediaPermissions,
                openAccessibilitySettings: permissionsStatus.openAccessibilitySettings
            )
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
            accessibilityGranted: accessibilityGranted,
            cameraGranted: cameraGranted,
            microphoneGranted: microphoneGranted,
            requestAccessibilityPermission: {
                // TODO(integration): permissionsManager.requestAccessibilityPermission()
            },
            requestMediaPermissions: {
                // TODO(integration): Task { await permissionsManager.requestMediaPermissions() }
            },
            openAccessibilitySettings: {
                // TODO(integration): permissionsManager.openAccessibilitySettings()
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
