import SwiftUI

/// First-run screen explaining what the app does and why it asks for
/// Accessibility and Camera/Microphone permissions. Shown once, gated by
/// the caller via `@AppStorage("hasCompletedOnboarding")`.
///
/// Plain view: takes booleans + closures rather than a `PermissionsManager`,
/// matching the decoupling pattern used by `MenuBarView`.
struct OnboardingView: View {
    var accessibilityGranted: Bool
    var mediaGranted: Bool

    var requestAccessibilityPermission: () -> Void
    var requestMediaPermissions: () -> Void
    var openAccessibilitySettings: () -> Void
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Welcome to Luxafor Monitor", systemImage: "flag.fill")
                    .font(.title2.bold())
                Text("Luxafor Monitor watches for Teams and Zoom meetings and turns your Luxafor light red while you're in one and green when you're free, so people around you know at a glance. You can always override it manually from the menu bar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            explanationSection(
                icon: "accessibility",
                title: "Accessibility access",
                body: "Used only to read the window titles and on-screen state of Teams and Zoom, so the app can tell when you've joined a call. It never types anything or controls any other app.",
                granted: accessibilityGranted,
                actionTitle: accessibilityGranted ? nil : "Grant Accessibility Access…",
                action: requestAccessibilityPermission
            )

            explanationSection(
                icon: "camera",
                title: "Camera & Microphone access",
                body: "Used only to observe whether some app is actively using your camera or microphone, as an extra signal that you're in a meeting. Luxafor Monitor never captures, records, or transmits any audio or video itself.",
                granted: mediaGranted,
                actionTitle: mediaGranted ? nil : "Grant Camera/Microphone Access…",
                action: requestMediaPermissions
            )

            if accessibilityGranted && !mediaGranted {
                // Nothing extra; media action button above covers it.
                EmptyView()
            }

            Spacer()

            HStack {
                if !accessibilityGranted {
                    Button("Open Accessibility Settings…") {
                        openAccessibilitySettings()
                    }
                }
                Spacer()
                Button("Get Started") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480, height: 480)
    }

    @ViewBuilder
    private func explanationSection(
        icon: String,
        title: String,
        body: String,
        granted: Bool,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? .green : .secondary)
            }
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.callout)
            }
        }
    }
}
