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
    ],
    targets: [
        .target(
            name: "stone_engine"
        ),
    ]
)
