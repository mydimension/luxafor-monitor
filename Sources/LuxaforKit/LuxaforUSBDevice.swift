import Foundation
import IOKit
import IOKit.hid

/// A minimal seam around actually writing bytes to a HID device.
///
/// `LuxaforUSBDevice` routes every outgoing command through a
/// `HIDReportWriter` instead of calling IOKit directly. That means the
/// device's connection/reconnection logic and the protocol's byte encoding
/// (`LuxaforProtocol`) can be exercised in unit tests with a fake writer,
/// with no real hardware or IOKit calls involved.
protocol HIDReportWriter: AnyObject {
    /// Writes a single HID output report. `report[0]` is treated as the
    /// HID report ID; the remaining bytes are the report payload.
    func write(_ report: [UInt8]) throws
}

/// The real, IOKit-backed `HIDReportWriter` used outside of tests.
final class IOKitHIDReportWriter: HIDReportWriter {
    private let device: IOHIDDevice

    init(device: IOHIDDevice) {
        self.device = device
    }

    func write(_ report: [UInt8]) throws {
        let reportID = CFIndex(report.first ?? 0)
        // For devices that don't use numbered reports (report ID 0),
        // IOHIDDeviceSetReport expects the ID byte to be omitted from the
        // payload -- passing it through shifts every subsequent byte by one
        // and the device silently ignores the malformed report.
        let payload = reportID == 0 ? Array(report.dropFirst()) : report
        let status: IOReturn = payload.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return kIOReturnError }
            return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, reportID, base, buffer.count)
        }
        guard status == kIOReturnSuccess else {
            throw LuxaforDeviceError.hidWriteFailed(status: status)
        }
    }
}

/// A real Luxafor device reached over USB HID via IOKit.
///
/// Locates the device by vendor ID (see `LuxaforProtocol.vendorID`),
/// opens it, and tolerates unplug/replug: an IOKit device-removal callback
/// flips `isConnected` to `false`, and a subsequent `setColor` call
/// transparently attempts to reconnect before giving up with
/// `LuxaforDeviceError.notConnected`.
public final class LuxaforUSBDevice: LuxaforDevice {
    /// `nil` only when constructed via the internal test seam
    /// (`init(writer:connected:)`), which bypasses IOKit entirely.
    private let manager: IOHIDManager?

    private let stateLock = NSLock()
    private var currentDevice: IOHIDDevice?
    private var writer: HIDReportWriter?
    private var connectedFlag = false

    public var isConnected: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return connectedFlag
    }

    public init() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchingDictionary: [String: Any] = [
            kIOHIDVendorIDKey: LuxaforProtocol.vendorID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDictionary as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        registerRemovalCallback(on: manager)
    }

    /// Test-only seam: wires the device directly to a caller-supplied
    /// writer and connection state, without touching IOKit. This lets unit
    /// tests exercise `setColor`/`turnOff`/reconnect behavior and verify the
    /// exact bytes written, using a mock `HIDReportWriter`.
    init(writer: HIDReportWriter, connected: Bool) {
        self.manager = nil
        self.writer = writer
        self.connectedFlag = connected
    }

    deinit {
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    public func connect() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard let manager = manager else {
            // Test seam instance: there is no real device to (re)connect to.
            if connectedFlag {
                return
            }
            throw LuxaforDeviceError.deviceNotFound
        }

        guard let matched = Self.matchingDevices(from: manager).first else {
            throw LuxaforDeviceError.deviceNotFound
        }

        let openStatus = IOHIDDeviceOpen(matched, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openStatus == kIOReturnSuccess else {
            throw LuxaforDeviceError.deviceNotFound
        }

        Self.warnIfUnrecognizedProductID(of: matched)

        currentDevice = matched
        writer = IOKitHIDReportWriter(device: matched)
        connectedFlag = true
    }

    public func setColor(_ color: LuxaforColor) throws {
        stateLock.lock()
        var activeWriter = connectedFlag ? writer : nil
        stateLock.unlock()

        if activeWriter == nil {
            // Tolerate unplug/replug: make a best-effort attempt to
            // reconnect before reporting failure.
            try? connect()
            stateLock.lock()
            activeWriter = connectedFlag ? writer : nil
            stateLock.unlock()
        }

        guard let writerToUse = activeWriter else {
            throw LuxaforDeviceError.notConnected
        }

        let report = LuxaforProtocol.staticColorReport(for: color)
        try writerToUse.write(report)
    }

    // MARK: - IOKit plumbing

    private func registerRemovalCallback(on manager: IOHIDManager) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            let instance = Unmanaged<LuxaforUSBDevice>.fromOpaque(context).takeUnretainedValue()
            instance.handleRemoval(of: device)
        }, context)
    }

    private func handleRemoval(of removedDevice: IOHIDDevice) {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let current = currentDevice, current == removedDevice {
            connectedFlag = false
            currentDevice = nil
            writer = nil
        }
    }

    private static func matchingDevices(from manager: IOHIDManager) -> [IOHIDDevice] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }
        return Array(deviceSet)
    }

    /// Luxafor Mini/Multi/Orb/Mute models may share the vendor ID but use a
    /// product ID that hasn't been confirmed for this implementation (see
    /// the sourcing notes in `LuxaforProtocol.swift`). Rather than refusing
    /// to talk to such a device, this logs a clear message so a user who
    /// hits it can report the PID for it to be added to the known list.
    private static func warnIfUnrecognizedProductID(of device: IOHIDDevice) {
        let productID = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int) ?? -1
        guard !LuxaforProtocol.knownProductIDs.contains(productID) else { return }
        let message = String(
            format: "LuxaforKit: connected to a Luxafor-vendor HID device with an unrecognized " +
                "product ID (0x%04X). It will still be sent standard static-color commands, but " +
                "please report this product ID so it can be added to LuxaforKit's known device list.\n",
            productID
        )
        FileHandle.standardError.write(Data(message.utf8))
    }
}
