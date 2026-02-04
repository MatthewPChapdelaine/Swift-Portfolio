// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftProject",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SwiftProject",
            targets: ["SwiftProject"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftProject",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftProjectTests",
            dependencies: ["SwiftProject"]
        ),
    ]
)
