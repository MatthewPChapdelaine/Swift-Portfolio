// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ChatApp",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ChatApp",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
            ]
        ),
    ]
)
