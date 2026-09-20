// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LuxaforMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LuxaforMonitorApp", targets: ["LuxaforMonitorApp"]),
        .library(name: "LuxaforKit", targets: ["LuxaforKit"]),
        .library(name: "MeetingDetectionKit", targets: ["MeetingDetectionKit"]),
    ],
    targets: [
        .target(
            name: "LuxaforKit"
        ),
        .target(
            name: "MeetingDetectionKit"
        ),
        .executableTarget(
            name: "LuxaforMonitorApp",
            dependencies: ["LuxaforKit", "MeetingDetectionKit"]
        ),
        .testTarget(
            name: "LuxaforKitTests",
            dependencies: ["LuxaforKit"]
        ),
        .testTarget(
            name: "MeetingDetectionKitTests",
            dependencies: ["MeetingDetectionKit"]
        ),
        .testTarget(
            name: "LuxaforMonitorAppTests",
            dependencies: ["LuxaforMonitorApp"]
        ),
    ]
)
