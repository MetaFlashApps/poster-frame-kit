import SwiftUI

struct DemoAnalyticsView: View {
    let viewModel: DemoViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Run Analytics", systemImage: "chart.bar.xaxis")
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

                if let comparison = viewModel.performanceComparison {
                    DemoAnalyticsSummaryView(comparison: comparison)
                    DemoTimingBreakdownView(comparison: comparison)

                    if let posterFrameTime = viewModel.selectionResult?.time,
                       let visionTime = viewModel.visionResult?.time {
                        DemoSelectionComparisonView(
                            posterFrameTime: posterFrameTime,
                            visionTime: visionTime
                        )
                    }

                    if viewModel.hasPendingOptionChanges {
                        Label(
                            "These measurements use the previous settings while the automatic update is prepared.",
                            systemImage: "clock.badge"
                        )
                        .foregroundStyle(.orange)
                    }
                } else if viewModel.isAnalyzing {
                    GroupBox {
                        ProgressView(
                            viewModel.analysisStage?.progressTitle
                                ?? "Preparing analytics…"
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                } else {
                    GroupBox {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: "chart.bar.xaxis",
                            description: Text(emptyDescription)
                        )
                        .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }

                DemoAnalyticsMethodologyView()
            }
            .padding()
        }
    }

    private var emptyTitle: String {
        viewModel.selectedURL == nil ? "No Measurements" : "Analytics Unavailable"
    }

    private var emptyDescription: String {
        if viewModel.selectedURL == nil {
            "Choose a video on the Results tab to run the comparison."
        } else {
            viewModel.visionEmptyDescription
        }
    }
}
