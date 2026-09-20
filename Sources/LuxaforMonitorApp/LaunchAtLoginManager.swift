import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for enabling/disabling
/// "Launch at Login". Self-contained — no dependency on other modules.
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app for launch-at-login. Errors are
    /// swallowed (surfaced only via `isEnabled` staying unchanged) since
    /// there's no good recovery action beyond letting the user retry.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("LaunchAtLoginManager: failed to update launch-at-login status: \(error)")
        }
    }
}
