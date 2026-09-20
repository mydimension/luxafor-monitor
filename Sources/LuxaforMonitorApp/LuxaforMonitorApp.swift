import SwiftUI

// Placeholder entry point. The real menu bar UI, AppState orchestration,
// preferences window, and onboarding flow are implemented on top of this
// scaffold (see the project plan / CONTRIBUTING.md).
@main
struct LuxaforMonitorApp: App {
    var body: some Scene {
        MenuBarExtra("Luxafor Monitor", systemImage: "flag.fill") {
            Text("Luxafor Monitor")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
