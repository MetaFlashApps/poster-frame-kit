import XCTest

@testable import PosterFrameDemo

final class DemoPreferenceKindTests: XCTestCase {
  func testAllSelectionPreferencesRemainVisible() {
    XCTAssertEqual(
      DemoPreferenceKind.allCases,
      [
        .midrollExclusion,
        .subtitleAvoidance,
        .facePreference,
        .aestheticPreference,
      ]
    )
  }

  func testEveryPreferenceHasCompactPresentationMetadata() {
    for kind in DemoPreferenceKind.allCases {
      XCTAssertFalse(kind.title.isEmpty)
      XCTAssertFalse(kind.systemImage.isEmpty)
      XCTAssertFalse(kind.helpText.isEmpty)
    }
  }
}
