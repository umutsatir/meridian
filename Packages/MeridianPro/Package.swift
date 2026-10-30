// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianPro",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianPro", targets: ["MeridianPro"]),
    ],
    targets: [
        .target(name: "MeridianPro"),
        .testTarget(name: "MeridianProTests", dependencies: ["MeridianPro"]),
    ]
)
