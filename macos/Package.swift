// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VesperMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VesperMac", targets: ["VesperMac"])
    ],
    targets: [
        .executableTarget(
            name: "VesperMac",
            path: "Sources/VesperMac"
        )
    ]
)
