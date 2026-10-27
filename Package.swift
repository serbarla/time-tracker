// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TimeTrackerCore", targets: ["TimeTrackerCore"]),
        .executable(name: "TimeTracker", targets: ["TimeTrackerApp"]),
    ],
    targets: [
        .target(name: "TimeTrackerCore"),
        .executableTarget(
            name: "TimeTrackerApp",
            dependencies: ["TimeTrackerCore"],
            resources: [.copy("Resources/Localization.json")]
        ),
        .testTarget(name: "TimeTrackerCoreTests", dependencies: ["TimeTrackerCore"]),
    ]
)
