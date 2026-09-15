import CoreGraphics
import XCTest

@testable import PosterFrameKit

final class PosterFrameOptionsTests: XCTestCase {
  func testDefaultOptionsAreAlreadyNormalized() throws {
    let options = PosterFrameOptions()

    XCTAssertEqual(try options.normalized(), options)
    XCTAssertNil(options.subtitleAvoidance)
    XCTAssertNil(options.facePreference)
    XCTAssertNil(options.aestheticPreference)
    XCTAssertEqual(PosterFrameSubtitleOptions().candidateCount, 8)
    XCTAssertEqual(PosterFrameFaceOptions().candidateCount, 8)
    XCTAssertEqual(PosterFrameAestheticOptions().candidateCount, 24)
    XCTAssertEqual(PosterFrameAestheticOptions().maximumAdjustment, 1)
  }

  func testSearchRangeIsClampedToNormalizedVideoBounds() throws {
    let options = PosterFrameOptions(searchRange: -0.25...1.25)

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.searchRange, 0...1)
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testSearchRangeOutsideVideoCollapsesToNearestBoundary() throws {
    let beforeVideo = try PosterFrameOptions(searchRange: -2 ... -1).normalized()
    let afterVideo = try PosterFrameOptions(searchRange: 2...3).normalized()

    XCTAssertEqual(beforeVideo.searchRange, 0...0)
    XCTAssertEqual(afterVideo.searchRange, 1...1)
  }

  func testNonFiniteSearchRangeIsRejected() {
    assertInvalid(
      PosterFrameOptions(searchRange: 0...Double.infinity)
    )
    assertInvalid(
      PosterFrameOptions(searchRange: -Double.infinity...0.5)
    )
  }

  func testNonPositiveMaximumFramesExaminedIsRejected() {
    assertInvalid(PosterFrameOptions(maximumFramesExamined: 0))
    assertInvalid(PosterFrameOptions(maximumFramesExamined: -1))
  }

  func testExcludedRangesAreClampedSortedAndMerged() throws {
    let options = PosterFrameOptions(
      excludedRanges: [
        0.8...1.5,
        -0.5...0.1,
        0.08...0.2,
        2...3,
      ]
    )

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.excludedRanges, [0...0.2, 0.8...1])
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testNonFiniteExcludedRangeIsRejected() {
    assertInvalid(
      PosterFrameOptions(excludedRanges: [0.4...Double.infinity])
    )
  }

  func testExclusionsCannotCoverCompleteSearchRange() {
    assertInvalid(
      PosterFrameOptions(
        searchRange: 0.2...0.8,
        excludedRanges: [0.1...0.9]
      )
    )
  }

  func testInvalidOutputSizeIsRejected() {
    let invalidSizes = [
      CGSize(width: 0, height: 360),
      CGSize(width: 640, height: -1),
      CGSize(width: CGFloat.infinity, height: 360),
      CGSize(width: 640, height: CGFloat.nan),
    ]

    for outputSize in invalidSizes {
      assertInvalid(PosterFrameOptions(outputSize: outputSize))
    }
  }

  func testCustomWeightsAreNormalizedWithoutChangingTheirProportions() throws {
    let options = PosterFrameOptions(
      profile: .custom(
        PosterFrameWeights(
          sharpness: 4,
          contrast: 2,
          entropy: 2,
          colorfulness: 2
        )
      )
    )

    let normalized = try options.normalized()
    guard case .custom(let weights) = normalized.profile else {
      return XCTFail("Expected custom profile")
    }

    XCTAssertEqual(weights.sharpness, 0.4, accuracy: 1e-12)
    XCTAssertEqual(weights.contrast, 0.2, accuracy: 1e-12)
    XCTAssertEqual(weights.entropy, 0.2, accuracy: 1e-12)
    XCTAssertEqual(weights.colorfulness, 0.2, accuracy: 1e-12)
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testVeryLargeCustomWeightsNormalizeWithoutOverflow() throws {
    let value = Double.greatestFiniteMagnitude
    let options = PosterFrameOptions(
      profile: .custom(
        PosterFrameWeights(
          sharpness: value,
          contrast: value,
          entropy: 0,
          colorfulness: 0
        )
      )
    )

    let normalized = try options.normalized()
    guard case .custom(let weights) = normalized.profile else {
      return XCTFail("Expected custom profile")
    }

    XCTAssertEqual(weights.sharpness, 0.5)
    XCTAssertEqual(weights.contrast, 0.5)
    XCTAssertEqual(weights.entropy, 0)
    XCTAssertEqual(weights.colorfulness, 0)
  }

  func testCustomWeightNormalizationIsExactlyIdempotent() throws {
    let options = PosterFrameOptions(
      profile: .custom(
        PosterFrameWeights(
          sharpness: 0.123,
          contrast: 4.567,
          entropy: 0.891,
          colorfulness: 2.345
        )
      )
    )

    let normalized = try options.normalized()

    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testInvalidCustomWeightsAreRejected() {
    assertInvalid(
      PosterFrameOptions(
        profile: .custom(
          PosterFrameWeights(
            sharpness: -1,
            contrast: 1,
            entropy: 1,
            colorfulness: 1
          )
        )
      )
    )
    assertInvalid(
      PosterFrameOptions(
        profile: .custom(
          PosterFrameWeights(
            sharpness: .infinity,
            contrast: 1,
            entropy: 1,
            colorfulness: 1
          )
        )
      )
    )
    assertInvalid(
      PosterFrameOptions(
        profile: .custom(
          PosterFrameWeights(
            sharpness: 0,
            contrast: 0,
            entropy: 0,
            colorfulness: 0
          )
        )
      )
    )
  }

}
