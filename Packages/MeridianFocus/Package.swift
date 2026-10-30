// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianFocus",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianFocus", targets: ["MeridianFocus"]),
    ],
    dependencies: [
        .package(path: "../MeridianCore"),
    ],
    targets: [
        .target(name: "MeridianFocus", dependencies: ["MeridianCore"]),
        .testTarget(name: "MeridianFocusTests", dependencies: ["MeridianFocus"]),
    ]
)
