// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Reminder",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Reminder",
            path: "Sources/Reminder",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
