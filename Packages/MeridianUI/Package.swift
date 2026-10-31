// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianUI",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianUI", targets: ["MeridianUI"]),
    ],
    targets: [
        .target(name: "MeridianUI", resources: [.copy("Resources/Fonts"), .copy("Resources/Paper")]),
        .testTarget(name: "MeridianUITests", dependencies: ["MeridianUI"], exclude: ["Fixtures"]),
    ]
)
