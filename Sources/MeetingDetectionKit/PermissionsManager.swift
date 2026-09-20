import AppKit
import ApplicationServices
import AVFoundation
import Combine
import Foundation

/// Tracks and requests the OS permissions this package's detectors depend
/// on: Accessibility (for `AccessibilityWindowDetector`, used by
/// `ZoomDetector`/`TeamsDetector`) and Camera/Microphone (for
/// `MediaUsageDetector`).
///
/// This app never actually reads screen content or captures audio/video —
/// it only reads window titles/AX metadata and a device's "in use" boolean —
/// but macOS still requires these permissions to be granted for the
/// underlying APIs to return real data, so requesting and clearly
/// explaining them to the user is an important, disclosure-worthy part of
/// onboarding.
@MainActor
public final class PermissionsManager: ObservableObject {
    @Published public private(set) var accessibilityGranted: Bool
    @Published public private(set) var cameraGranted: Bool
    @Published public private(set) var microphoneGranted: Bool

    public init() {
        accessibilityGranted = AXIsProcessTrusted()
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Re-checks all three permission states and updates the published
    /// properties. Cheap and side-effect-free (does not prompt); safe to
    /// call e.g. whenever the app becomes active again, since the user may
    /// have changed permissions in System Settings.
    public func refreshStatus() {
        accessibilityGranted = AXIsProcessTrusted()
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Prompts the user with the system Accessibility permission dialog if
    /// not already granted (via `kAXTrustedCheckOptionPrompt`). Does not
    /// synchronously update `accessibilityGranted` — call `refreshStatus()`
    /// afterward (e.g. when the app regains focus) to pick up the result,
    /// since granting Accessibility permission typically requires the user
    /// to visit System Settings regardless of this prompt.
    public func requestAccessibilityPermission() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refreshStatus()
    }

    /// Requests camera and microphone permission via the standard
    /// AVFoundation authorization dialogs, then updates published state to
    /// reflect the result.
    public func requestMediaPermissions() async {
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        cameraGranted = videoGranted
        microphoneGranted = audioGranted
    }

    /// Opens System Settings directly to the Accessibility privacy pane, for
    /// use when the user needs to manually grant (or has previously denied
    /// and must now toggle) Accessibility permission.
    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
