import SwiftUI

struct DemoCandidateBrowserView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        GroupBox {
            DemoCandidateStripView(
                candidates: viewModel.candidateFrames,
                expectedCount: viewModel.maximumFramesExamined,
                officialCandidateID: viewModel.officialCandidateID,
                browsedCandidateID: viewModel.browsedCandidateID,
                isUpdating: viewModel.isAnalyzing
                    || viewModel.isAutoRunPending,
                selectCandidate: viewModel.browseCandidate
            )
        } label: {
            Label("Candidate Browser", systemImage: "chart.bar.xaxis")
        }
    }
}
