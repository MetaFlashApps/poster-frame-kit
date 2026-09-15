import CoreMedia
import CoreVideo
import PosterFrameKit
@testable import PosterFrameDemo
import XCTest

final class VisionComparisonRunnerTests: XCTestCase {
    func testVisionRanksSyntheticCandidatesOnSupportedSystems() async throws {
        guard #available(macOS 15.0, *) else {
            throw XCTSkip("Apple Image Aesthetics requires macOS 15 or newer.")
        }

        let samples = try [
            sample(seed: 0, time: 1),
            sample(seed: 1, time: 2),
        ]
        let comparison = try await VisionComparisonRunner.run(
            samples: samples,
            profile: .animation
        )

        XCTAssertGreaterThan(comparison.vision.image.width, 0)
        XCTAssertGreaterThan(comparison.hybrid.image.height, 0)
        XCTAssertTrue(comparison.vision.time.isNumeric)
        XCTAssertTrue(comparison.hybrid.time.isNumeric)
    }

    private func sample(seed: UInt8, time: Double) throws -> PosterFrameSample {
        let width = 128
        let height = 128
        var optionalPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &optionalPixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        let pixelBuffer = try XCTUnwrap(optionalPixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }
        let baseAddress = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<height {
            let row = baseAddress
                .advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                let checker = UInt8((x / 8 + y / 8) % 2) * 160
                row[offset] = checker &+ seed * 20
                row[offset + 1] = UInt8((x * 2 + Int(seed) * 30) % 256)
                row[offset + 2] = UInt8((y * 2 + Int(seed) * 40) % 256)
                row[offset + 3] = 255
            }
        }

        let timestamp = CMTime(seconds: time, preferredTimescale: 600)
        return PosterFrameSample(
            pixelBuffer: pixelBuffer,
            requestedTime: timestamp,
            actualTime: timestamp
        )
    }
}
