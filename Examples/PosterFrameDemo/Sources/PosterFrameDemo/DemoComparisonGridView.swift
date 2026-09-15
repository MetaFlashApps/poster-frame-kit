import SwiftUI

struct DemoComparisonGridView: View {
    let viewModel: DemoViewModel

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: 250),
                    spacing: 16,
                    alignment: .top
                )
            ],
            alignment: .leading,
            spacing: 16
        ) {
            DemoFrameCard(
                title: "Apple Vision",
                image: viewModel.visionResult?.image,
                videoPosition: viewModel.videoPosition(
                    for: viewModel.visionResult?.time
                ),
                processingDuration: viewModel.visionDuration,
                timeUnavailableText: nil,
                accessibilityLabel: "Poster frame selected by Apple Vision",
                emptyTitle: viewModel.visionEmptyTitle,
                emptyDescription: viewModel.visionEmptyDescription,
                detailText: viewModel.visionDetailText,
                candidateCaptureDuration: viewModel.comparisonCaptureDuration,
                processingLabel: "Ranking Only",
                processingHelp: "Ranks the separately captured candidates; video decoding is shown as Candidate Capture.",
                isWorking: viewModel.isVisionComparisonLoading,
                workingDescription: viewModel.visionWorkingDescription,
                isUpdating: viewModel.isUpdatingResults
            )

            DemoFrameCard(
                title: "PFK + Vision 50/50",
                image: viewModel.hybridResult?.image,
                videoPosition: viewModel.videoPosition(
                    for: viewModel.hybridResult?.time
                ),
                processingDuration: nil,
                timeUnavailableText: nil,
                accessibilityLabel: "Poster frame selected by the PosterFrameKit and Apple Vision hybrid",
                emptyTitle: viewModel.visionEmptyTitle,
                emptyDescription: viewModel.visionEmptyDescription,
                detailText: viewModel.hybridDetailText,
                isWorking: viewModel.isVisionComparisonLoading,
                workingDescription: viewModel.visionWorkingDescription,
                isUpdating: viewModel.isUpdatingResults
            )

            DemoFrameCard(
                title: "50% Midpoint Baseline",
                image: viewModel.baselineFrame?.image,
                videoPosition: viewModel.videoPosition(
                    for: viewModel.baselineFrame?.time
                ),
                processingDuration: nil,
                timeUnavailableText: nil,
                accessibilityLabel: "Baseline frame at 50 percent of the video duration",
                emptyTitle: "No Video Selected",
                emptyDescription: "Choose a video to load the baseline frame.",
                isWorking: viewModel.isLoadingBaseline,
                workingDescription: "Loading the 50% baseline…"
            )
        }
    }
}
