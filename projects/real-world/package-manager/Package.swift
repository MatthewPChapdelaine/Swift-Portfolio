// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PackageManager",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PackageManager",
            dependencies: ["Yams"]
        ),
    ]
)
