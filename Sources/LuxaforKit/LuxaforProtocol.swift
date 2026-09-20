import Foundation

/// Pure byte-encoding logic for the Luxafor USB HID "static color" command.
///
/// This is deliberately decoupled from any actual HID I/O (see
/// `LuxaforUSBDevice.swift`) so the wire-format logic can be unit tested
/// without hardware.
///
/// ## Protocol facts and sourcing
///
/// This is a clean-room reimplementation: no source code was copied from any
/// third-party project. The facts below (device identifiers and the output
/// report byte layout) are, however, widely and independently documented
/// across several public open-source Luxafor client libraries and were
/// cross-checked against multiple of them before being encoded here:
///
///  - **USB identifiers.** Vendor ID `0x04D8` (1240 decimal, assigned to
///    Microchip Technology Inc.) and Product ID `0xF372` (62322 decimal) for
///    the Luxafor Flag are corroborated by: the pyluxa4 project's published
///    USB API reference (facelessuser.github.io/pyluxa4/usb), the
///    MarcMeszaros/luxafor-go Go package, fmartingr/pyluxafor's udev rules,
///    and JnyJny/busylight's device table. Several of these sources note
///    that other Luxafor models (Mini, Multi, Orb, Mute) enumerate under the
///    same vendor ID and, per some sources, the same generic product ID as
///    the Flag. That sharing has **not** been verified against real
///    Mini/Multi/Orb/Mute hardware by this implementation, so
///    `LuxaforUSBDevice` treats any device matching the vendor ID as
///    plausible even if its product ID isn't in `knownProductIDs`, rather
///    than hard-failing.
///  - **"Set static color" output report layout**, corroborated by the same
///    sources: byte 0 is the HID report ID (`0x00`, i.e. the device does not
///    use numbered reports), byte 1 is the command/mode byte (`0x01` means
///    "set static color"), byte 2 is the LED target (`0xFF` addresses every
///    LED; some sources also document `0x41`/`0x42` for front/back LED
///    banks and `1`-`6` for individual LEDs on multi-LED models), and bytes
///    3-5 hold the red, green, and blue channel values respectively.
///    Multiple sources describe the underlying HID output report as a fixed
///    9-byte buffer (a 1-byte report ID plus an 8-byte payload), with any
///    bytes beyond the ones described above left as zero padding.
///
/// If real hardware disagrees with any of this (a different report length,
/// an unexpected command byte, etc.), this file and `knownProductIDs` in
/// `LuxaforUSBDevice.swift` are the only places that should need to change.
enum LuxaforProtocol {
    /// USB vendor ID shared by Luxafor devices (Microchip Technology Inc.).
    static let vendorID: Int = 0x04D8

    /// USB product IDs known to speak this exact protocol. Currently just
    /// the Luxafor Flag's documented PID. Devices matching `vendorID` but
    /// not this set are still attempted (see `LuxaforUSBDevice`) since other
    /// Luxafor models may share it or use an as-yet-unconfirmed PID.
    static let knownProductIDs: Set<Int> = [0xF372]

    /// LED target byte selecting every LED on the device.
    static let allLEDs: UInt8 = 0xFF

    /// Command byte identifying a "set static color" instruction.
    private static let staticColorCommand: UInt8 = 0x01

    /// Total size, in bytes, of the HID output report: 1 report-ID byte
    /// followed by an 8-byte command payload.
    static let reportLength = 9

    /// Encodes a "set static color" HID output report for `color`.
    ///
    /// - Parameters:
    ///   - color: The RGB color to encode.
    ///   - ledTarget: Which LED(s) to target. Defaults to `allLEDs`.
    /// - Returns: A `reportLength`-byte array ready to hand to an HID output
    ///   report write call, laid out as
    ///   `[reportID, command, ledTarget, red, green, blue, 0, 0, 0]`.
    static func staticColorReport(for color: LuxaforColor, ledTarget: UInt8 = allLEDs) -> [UInt8] {
        var report = [UInt8](repeating: 0x00, count: reportLength)
        report[0] = 0x00 // HID report ID: this device does not use numbered reports.
        report[1] = staticColorCommand
        report[2] = ledTarget
        report[3] = color.red
        report[4] = color.green
        report[5] = color.blue
        return report
    }
}
