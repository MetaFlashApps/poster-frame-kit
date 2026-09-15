import XCTest

@testable import PosterFrameDemo

final class DemoSectionTests: XCTestCase {
    func testBottomNavigationContainsResultsMetricsAndAnalytics() {
        XCTAssertEqual(
            DemoSection.allCases.map(\.title),
            ["Results", "Metrics", "Analytics"]
        )
        XCTAssertEqual(
            DemoSection.allCases.map(\.systemImage),
            [
                "photo.on.rectangle.angled",
                "chart.bar.fill",
                "chart.bar.xaxis",
            ]
        )
    }
}
