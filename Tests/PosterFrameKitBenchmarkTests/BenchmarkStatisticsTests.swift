import XCTest

@testable import PosterFrameKitBenchmark

final class BenchmarkStatisticsTests: XCTestCase {
  func testMedianHandlesOddAndEvenSamples() {
    XCTAssertEqual(median([1, 2, 3]), 2)
    XCTAssertEqual(median([1, 2, 3, 4]), 2.5)
    XCTAssertEqual(
      median([Double.greatestFiniteMagnitude / 2, Double.greatestFiniteMagnitude]),
      Double.greatestFiniteMagnitude * 0.75
    )
    XCTAssertEqual(median([]), 0)
  }

  func testByteMedianPreservesOddHalvesWithoutOverflow() {
    XCTAssertEqual(medianBytes([1, 3]), 2)
    XCTAssertEqual(medianBytes([UInt64.max - 2, UInt64.max]), UInt64.max - 1)
  }
}
