// swift-tools-version: 6.0
import PackageDescription

// The executable name must stay in sync with CFBundleExecutable in bundle.sh.
let appName = "ferriteSuite"

let package = Package(
    name: appName,
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: appName, targets: [appName])
    ],
    targets: [
        .executableTarget(
            name: appName,
            path: "Sources/ferriteSuite"
        )
    ]
)
