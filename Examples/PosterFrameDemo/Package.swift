// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PosterFrameDemo",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "PosterFrameDemo",
            dependencies: [
                .product(name: "PosterFrameKit", package: "poster-frame-kit"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PosterFrameDemoTests",
            dependencies: ["PosterFrameDemo"]
        ),
    ]
)
