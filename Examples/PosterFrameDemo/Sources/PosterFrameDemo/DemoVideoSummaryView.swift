import SwiftUI

struct DemoVideoSummaryView: View {
    let viewModel: DemoViewModel

    var body: some View {
        HStack {
            if let selectedFileName = viewModel.selectedFileName {
                Label(selectedFileName, systemImage: "doc.richtext")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Selected video: \(selectedFileName)")

                if let duration = viewModel.selectedVideoDurationText {
                    Text("· \(duration)")
                        .monospacedDigit()
                }
            } else {
                Label("Choose a video to start", systemImage: "doc.richtext")
            }

            Spacer()

            DemoAnalysisStatusView(viewModel: viewModel)

            if let duration = viewModel.posterFrameDuration {
                LabeledContent {
                    DemoDurationValue(duration: duration)
                } label: {
                    Label("End-to-end", systemImage: "bolt.fill")
                }
                .fixedSize()
                .help("PosterFrameKit duration loading, decoding, analysis, refinements, and ranking.")
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
