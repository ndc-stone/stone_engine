// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "stone_engine",
    platforms: [
        .iOS(.v15), .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "stone_engine",
            targets: ["stone_engine"]
        ),
    ],
    targets: [
        .target(
            name: "stone_engine"
        ),
    ]
)
