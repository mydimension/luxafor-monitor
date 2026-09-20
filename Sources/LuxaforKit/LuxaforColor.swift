import Foundation

/// An RGB color value understood by a Luxafor device.
public struct LuxaforColor: Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let red = LuxaforColor(red: 255, green: 0, blue: 0)
    public static let green = LuxaforColor(red: 0, green: 255, blue: 0)
    public static let off = LuxaforColor(red: 0, green: 0, blue: 0)
}
