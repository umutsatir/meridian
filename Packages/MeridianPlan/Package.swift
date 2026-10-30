// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianPlan",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianPlan", targets: ["MeridianPlan"]),
    ],
    dependencies: [
        .package(path: "../MeridianCore"),
    ],
    targets: [
        .target(name: "MeridianPlan", dependencies: ["MeridianCore"]),
        .testTarget(name: "MeridianPlanTests", dependencies: ["MeridianPlan", "MeridianCore"]),
    ]
)
