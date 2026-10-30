// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianMaps",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MeridianMaps", targets: ["MeridianMaps"]),
    ],
    dependencies: [
        .package(path: "../MeridianCore"),
    ],
    targets: [
        .target(
            name: "MeridianMaps",
            dependencies: ["MeridianCore"],
            resources: [
                .copy("Resources/map-europe-land.svg"),
                .copy("Resources/map-europe-borders.svg"),
                .copy("Resources/terrain-fields.jpg"),
                .copy("Resources/world.json"),
                .copy("Resources/design-airports.json"),
            ]
        ),
        .testTarget(name: "MeridianMapsTests", dependencies: ["MeridianMaps"]),
    ]
)
