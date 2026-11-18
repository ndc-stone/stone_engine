// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "stone_engine",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        .library(
            name: "stone_engine",
            targets: ["stone_engine"]
        ),
        .library(
            name: "StoneEngineSwiftUI",
            targets: ["StoneEngineSwiftUI"]
        ),
    ],
    targets: [
        .target(
            name: "stone_engine"
        ),
        .target(
            name: "StoneEngineSwiftUI",
            dependencies: ["stone_engine"]
        ),
        .testTarget(
            name: "StoneEngineSwiftUITests",
            dependencies: ["StoneEngineSwiftUI"]
        ),
        .testTarget(
            name: "stone_engineTests",
            dependencies: ["stone_engine"],
            exclude: ["__Snapshots__"]
        ),
    ]
)
