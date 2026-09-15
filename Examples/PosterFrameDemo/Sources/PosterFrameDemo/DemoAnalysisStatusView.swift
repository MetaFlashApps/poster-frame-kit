import SwiftUI

struct DemoAnalysisStatusView: View {
    let viewModel: DemoViewModel

    var body: some View {
        Group {
            if viewModel.isAutoRunPending {
                ProgressView("Updating automatically…")
                    .controlSize(.small)
            } else if let analysisStage = viewModel.analysisStage {
                ProgressView(analysisStage.progressTitle)
                    .controlSize(.small)
            } else if viewModel.isLoadingBaseline {
                ProgressView("Loading 50% baseline…")
                    .controlSize(.small)
            } else if viewModel.hasPendingOptionChanges {
                Label(
                    "Waiting to update",
                    systemImage: "clock.badge"
                )
                .foregroundStyle(.orange)
            } else if viewModel.selectionResult != nil {
                Label("Comparison ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if viewModel.selectedURL != nil {
                Label("Ready", systemImage: "film.stack")
                    .foregroundStyle(.secondary)
            } else {
                Label("Selection starts automatically", systemImage: "bolt.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}
