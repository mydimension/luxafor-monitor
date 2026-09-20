import XCTest
@testable import LuxaforKit

/// A fake `HIDReportWriter` that records every report it's asked to write,
/// so tests can assert on exact bytes without any real HID I/O.
private final class MockHIDReportWriter: HIDReportWriter {
    private(set) var writtenReports: [[UInt8]] = []
    var errorToThrow: Error?

    func write(_ report: [UInt8]) throws {
        if let errorToThrow = errorToThrow {
            throw errorToThrow
        }
        writtenReports.append(report)
    }
}

final class LuxaforUSBDeviceTests: XCTestCase {
    func testSetColorBeforeConnectThrowsNotConnected() {
        let device = LuxaforUSBDevice(writer: MockHIDReportWriter(), connected: false)

        XCTAssertThrowsError(try device.setColor(.red)) { error in
            XCTAssertEqual(error as? LuxaforDeviceError, .notConnected)
        }
    }

    func testSetColorWritesExpectedReportWhenConnected() throws {
        let writer = MockHIDReportWriter()
        let device = LuxaforUSBDevice(writer: writer, connected: true)

        try device.setColor(.green)

        XCTAssertEqual(writer.writtenReports.count, 1)
        XCTAssertEqual(writer.writtenReports[0], LuxaforProtocol.staticColorReport(for: .green))
    }

    func testSetColorWithCustomRGBWritesExactBytes() throws {
        let writer = MockHIDReportWriter()
        let device = LuxaforUSBDevice(writer: writer, connected: true)
        let color = LuxaforColor(red: 10, green: 20, blue: 30)

        try device.setColor(color)

        XCTAssertEqual(writer.writtenReports.last, [0x00, 0x01, 0xFF, 10, 20, 30, 0x00, 0x00, 0x00])
    }

    func testTurnOffWritesOffReport() throws {
        let writer = MockHIDReportWriter()
        let device = LuxaforUSBDevice(writer: writer, connected: true)

        try device.turnOff()

        XCTAssertEqual(writer.writtenReports.last, LuxaforProtocol.staticColorReport(for: .off))
    }

    func testHIDWriteFailurePropagates() {
        let writer = MockHIDReportWriter()
        writer.errorToThrow = LuxaforDeviceError.hidWriteFailed(status: -1)
        let device = LuxaforUSBDevice(writer: writer, connected: true)

        XCTAssertThrowsError(try device.setColor(.red)) { error in
            XCTAssertEqual(error as? LuxaforDeviceError, .hidWriteFailed(status: -1))
        }
    }

    func testIsConnectedReflectsInjectedState() {
        let connectedDevice = LuxaforUSBDevice(writer: MockHIDReportWriter(), connected: true)
        XCTAssertTrue(connectedDevice.isConnected)

        let disconnectedDevice = LuxaforUSBDevice(writer: MockHIDReportWriter(), connected: false)
        XCTAssertFalse(disconnectedDevice.isConnected)
    }
}
