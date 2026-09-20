import SwiftUI
import AppKit
import LuxaforKit

/// Bridging between `LuxaforKit.LuxaforColor` (a plain RGB triple) and
/// SwiftUI's `Color`, shared by the menu bar icon, `MenuBarView`, and
/// `PreferencesView`.
extension LuxaforColor {
    var swiftUIColor: Color {
        Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }

    init(swiftUIColor: Color) {
        // NSColor bridging (rather than `Color.resolve(in:)`, which needs
        // macOS 14+) keeps this compatible with the app's macOS 13 minimum.
        let nsColor = NSColor(swiftUIColor).usingColorSpace(.deviceRGB) ?? NSColor(swiftUIColor)
        self.init(
            red: UInt8(clamping: Int((nsColor.redComponent * 255).rounded())),
            green: UInt8(clamping: Int((nsColor.greenComponent * 255).rounded())),
            blue: UInt8(clamping: Int((nsColor.blueComponent * 255).rounded()))
        )
    }
}
