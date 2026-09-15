// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PosterFrameKit",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "PosterFrameKit", targets: ["PosterFrameKit"])
  ],
  targets: [
    .target(
      name: "PosterFrameKit"
    ),
    .target(
      name: "PosterFrameKitBenchmarkSupport",
      path: "Benchmarks/PosterFrameKitBenchmarkSupport"
    ),
    .executableTarget(
      name: "PosterFrameKitBenchmark",
      dependencies: ["PosterFrameKit", "PosterFrameKitBenchmarkSupport"],
      path: "Benchmarks/PosterFrameKitBenchmark"
    ),
    .executableTarget(
      name: "PosterFrameKitQualityBenchmark",
      dependencies: ["PosterFrameKit", "PosterFrameKitBenchmarkSupport"],
      path: "Benchmarks/PosterFrameKitQualityBenchmark"
    ),
    .executableTarget(
      name: "PosterFrameKitSubtitleBenchmark",
      dependencies: ["PosterFrameKit"],
      path: "Benchmarks/PosterFrameKitSubtitleBenchmark"
    ),
    .testTarget(
      name: "PosterFrameKitTests",
      dependencies: ["PosterFrameKit"]
    ),
    .testTarget(
      name: "PosterFrameKitBenchmarkTests",
      dependencies: [
        "PosterFrameKit",
        "PosterFrameKitBenchmark",
        "PosterFrameKitBenchmarkSupport",
      ]
    ),
    .testTarget(
      name: "PosterFrameKitQualityBenchmarkTests",
      dependencies: [
        "PosterFrameKitQualityBenchmark",
        "PosterFrameKitBenchmarkSupport",
      ]
    ),
    .testTarget(
      name: "PosterFrameKitSubtitleBenchmarkTests",
      dependencies: ["PosterFrameKitSubtitleBenchmark"]
    ),
  ]
)
