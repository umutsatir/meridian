// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianCore", targets: ["MeridianCore"]),
    ],
    targets: [
        .target(name: "MeridianCore", resources: [.copy("Resources/airports.json")]),
        .testTarget(name: "MeridianCoreTests", dependencies: ["MeridianCore"]),
    ]
)
