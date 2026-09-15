import CoreGraphics
import XCTest

@testable import PosterFrameKit

final class PosterFrameRefinementOptionsTests: XCTestCase {
  func testAestheticCandidateCountIsBoundedByMainCandidateBudget() throws {
    let options = PosterFrameOptions(
      maximumFramesExamined: 3,
      aestheticPreference: PosterFrameAestheticOptions(candidateCount: 8)
    )

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.aestheticPreference?.candidateCount, 3)
    XCTAssertEqual(
      normalized.aestheticPreference?.maximumAdjustment,
      1
    )
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testInvalidAestheticOptionsAreRejected() {
    assertInvalid(
      PosterFrameOptions(
        aestheticPreference: PosterFrameAestheticOptions(
          candidateCount: 0
        )
      )
    )
    for adjustment in [-0.1, 1.1, .infinity, .nan] {
      assertInvalid(
        PosterFrameOptions(
          aestheticPreference: PosterFrameAestheticOptions(
            maximumAdjustment: adjustment
          )
        )
      )
    }
  }

  func testFaceCandidateCountIsBoundedByMainCandidateBudget() throws {
    let options = PosterFrameOptions(
      maximumFramesExamined: 2,
      facePreference: PosterFrameFaceOptions(candidateCount: 4)
    )

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.facePreference?.candidateCount, 2)
    XCTAssertEqual(normalized.facePreference?.maximumBonus, 0.04)
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testInvalidFaceOptionsAreRejected() {
    assertInvalid(
      PosterFrameOptions(
        facePreference: PosterFrameFaceOptions(candidateCount: 0)
      )
    )
    for bonus in [-0.1, 1.1, .infinity, .nan] {
      assertInvalid(
        PosterFrameOptions(
          facePreference: PosterFrameFaceOptions(maximumBonus: bonus)
        )
      )
    }
  }

  func testSubtitleCandidateCountIsBoundedByMainCandidateBudget() throws {
    let options = PosterFrameOptions(
      maximumFramesExamined: 2,
      subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 5)
    )

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.subtitleAvoidance?.candidateCount, 2)
    XCTAssertEqual(normalized.subtitleAvoidance?.maximumPenalty, 0.08)
    XCTAssertEqual(try normalized.normalized(), normalized)
  }

  func testInvalidSubtitleOptionsAreRejected() {
    assertInvalid(
      PosterFrameOptions(
        subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 0)
      )
    )
    for penalty in [-0.1, 1.1, .infinity, .nan] {
      assertInvalid(
        PosterFrameOptions(
          subtitleAvoidance: PosterFrameSubtitleOptions(
            maximumPenalty: penalty
          )
        )
      )
    }
  }

}
