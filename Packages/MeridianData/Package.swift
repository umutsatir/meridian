// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianData",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianData", targets: ["MeridianData"]),
    ],
    dependencies: [
        .package(path: "../MeridianCore"),
    ],
    targets: [
        .target(name: "MeridianData", dependencies: ["MeridianCore"]),
        .testTarget(name: "MeridianDataTests", dependencies: ["MeridianData"]),
    ]
)
