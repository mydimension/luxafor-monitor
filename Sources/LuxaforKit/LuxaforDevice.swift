import Foundation

/// Errors surfaced by a `LuxaforDevice` implementation.
public enum LuxaforDeviceError: Error, Equatable, Sendable {
    /// No matching Luxafor USB HID device was found while enumerating.
    case deviceNotFound
    /// A command was issued before `connect()` succeeded.
    case notConnected
    /// The underlying HID write failed. `status` is the IOKit/IOReturn code.
    case hidWriteFailed(status: Int32)
}

/// Abstraction over a physical (or mock) Luxafor device.
///
/// Concrete implementations are responsible for locating the device,
/// maintaining the connection (including tolerating unplug/replug), and
/// encoding `LuxaforColor` values into whatever wire protocol the transport
/// (USB HID, Bluetooth, etc.) requires.
public protocol LuxaforDevice: AnyObject {
    /// Whether the device is currently connected and ready to accept commands.
    var isConnected: Bool { get }

    /// Attempts to locate and open the device. Safe to call again if the
    /// device was disconnected.
    func connect() throws

    /// Sets all LEDs to a static color.
    func setColor(_ color: LuxaforColor) throws

    /// Convenience for `setColor(.off)`.
    func turnOff() throws
}

public extension LuxaforDevice {
    func turnOff() throws {
        try setColor(.off)
    }
}
