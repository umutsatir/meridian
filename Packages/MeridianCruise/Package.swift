// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianCruise",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianCruise", targets: ["MeridianCruise"]),
    ],
    dependencies: [
        .package(path: "../MeridianCore"),
    ],
    targets: [
        .target(name: "MeridianCruise", dependencies: ["MeridianCore"]),
        .testTarget(name: "MeridianCruiseTests", dependencies: ["MeridianCruise", "MeridianCore"]),
    ]
)
