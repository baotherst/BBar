// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BBar", targets: ["BBar"])
    ],
    targets: [
        .executableTarget(
            name: "BBar",
            dependencies: [],
            path: "Sources/BBar"
        )
    ]
)
