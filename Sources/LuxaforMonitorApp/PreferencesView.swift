import SwiftUI
import LuxaforKit

/// Preferences window content, for use inside a `Settings { }` scene.
///
/// Takes everything as bindings/plain values rather than concrete detector
/// or coordinator types, so it stays buildable without `MeetingDetectionKit`'s
/// concrete detectors. At integration time, `detectorEnabled` keys should
/// match the detector display names the integrator registers with the
/// `DetectionCoordinator` (e.g. "Zoom", "Microsoft Teams", "Media Usage").
struct PreferencesView: View {
    @Binding var detectorEnabled: [String: Bool]
    @Binding var pollInterval: Double
    @Binding var colorForInMeeting: LuxaforColor
    @Binding var colorForNotInMeeting: LuxaforColor

    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.isEnabled

    private static let detectorOrder = ["Zoom", "Microsoft Teams", "Media Usage"]

    var body: some View {
        Form {
            Section("Detectors") {
                ForEach(orderedDetectorNames, id: \.self) { name in
                    Toggle(name, isOn: bindingForDetector(name))
                }

                HStack {
                    Text("Check every")
                    Slider(value: $pollInterval, in: 1...15, step: 1)
                    Text("\(Int(pollInterval))s")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
            }

            Section("Light Colors") {
                ColorPicker(
                    "In a meeting",
                    selection: Binding(
                        get: { colorForInMeeting.swiftUIColor },
                        set: { colorForInMeeting = LuxaforColor(swiftUIColor: $0) }
                    ),
                    supportsOpacity: false
                )
                ColorPicker(
                    "Not in a meeting",
                    selection: Binding(
                        get: { colorForNotInMeeting.swiftUIColor },
                        set: { colorForNotInMeeting = LuxaforColor(swiftUIColor: $0) }
                    ),
                    supportsOpacity: false
                )
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        launchAtLoginEnabled = newValue
                        LaunchAtLoginManager.setEnabled(newValue)
                    }
                ))
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var orderedDetectorNames: [String] {
        let known = Self.detectorOrder.filter { detectorEnabled[$0] != nil }
        let extras = detectorEnabled.keys.filter { !Self.detectorOrder.contains($0) }.sorted()
        return known + extras
    }

    private func bindingForDetector(_ name: String) -> Binding<Bool> {
        Binding(
            get: { detectorEnabled[name] ?? true },
            set: { detectorEnabled[name] = $0 }
        )
    }
}
