enum DemoSection: CaseIterable, Identifiable {
    case results
    case metrics
    case analytics

    var id: Self { self }

    var title: String {
        switch self {
        case .results:
            "Results"
        case .metrics:
            "Metrics"
        case .analytics:
            "Analytics"
        }
    }

    var systemImage: String {
        switch self {
        case .results:
            "photo.on.rectangle.angled"
        case .metrics:
            "chart.bar.fill"
        case .analytics:
            "chart.bar.xaxis"
        }
    }
}
