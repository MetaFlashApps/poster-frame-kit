import SwiftUI

struct DemoMetricsView: View {
    let viewModel: DemoViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("PosterFrameKit Metrics", systemImage: "chart.bar.fill")
                        .font(.title2)
                        .bold()
                    Spacer()
                    if let selectedFileName = viewModel.selectedFileName {
                        Text(selectedFileName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let result = viewModel.selectionResult {
                    DemoScoreSummaryView(result: result)
                    DemoRefinementBreakdownView(
                        result: result,
                        options: viewModel.appliedOptions
                    )
                    DemoResultMetricsView(metrics: result.metrics)

                    if viewModel.hasPendingOptionChanges {
                        Label(
                            "These metrics use the previous settings while the automatic update is prepared.",
                            systemImage: "clock.badge"
                        )
                        .foregroundStyle(.orange)
                    }
                } else if viewModel.isPosterFrameLoading {
                    GroupBox {
                        ProgressView("PosterFrameKit is measuring candidates…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                } else {
                    GroupBox {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: "chart.bar.fill",
                            description: Text(emptyDescription)
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
            }
            .padding()
        }
    }

    private var emptyTitle: String {
        viewModel.selectedURL == nil ? "No Metrics" : "Metrics Unavailable"
    }

    private var emptyDescription: String {
        if viewModel.selectedURL == nil {
            "Choose a video on the Results tab to analyze a poster frame."
        } else {
            "PosterFrameKit has not produced a result for this video."
        }
    }
}
