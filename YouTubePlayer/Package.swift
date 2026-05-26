// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YouTubePlayer",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "YouTubePlayer",
            targets: ["YouTubePlayer"]
        )
    ],
    targets: [
        .target(
            name: "YouTubePlayer",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "YouTubePlayerTests",
            dependencies: ["YouTubePlayer"]
        )
    ]
)
