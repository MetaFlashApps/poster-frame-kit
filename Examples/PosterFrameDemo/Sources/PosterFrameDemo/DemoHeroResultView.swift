import SwiftUI
import UniformTypeIdentifiers

struct DemoHeroResultView: View {
    @State private var isShowingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var isDropTargeted = false

    let viewModel: DemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    DemoHeroTitleView(
                        title: heroTitle,
                        isRecommendation: viewModel.isHeroRecommendation,
                        showsStatus: viewModel.selectedURL != nil
                    )
                    Spacer()
                    DemoHeroSummaryView(
                        videoPosition: viewModel.videoPosition(
                            for: viewModel.heroTime
                        ),
                        score: viewModel.heroScore
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    DemoHeroTitleView(
                        title: heroTitle,
                        isRecommendation: viewModel.isHeroRecommendation,
                        showsStatus: viewModel.selectedURL != nil
                    )
                    DemoHeroSummaryView(
                        videoPosition: viewModel.videoPosition(
                            for: viewModel.heroTime
                        ),
                        score: viewModel.heroScore
                    )
                }
            }

            DemoFrameSurface(
                image: viewModel.heroImage,
                accessibilityLabel: accessibilityLabel,
                emptyTitle: viewModel.selectedURL == nil
                    ? "Drop Video Here"
                    : "Selecting Poster Frame",
                emptyDescription: viewModel.selectedURL == nil
                    ? "Or choose Video… in the header."
                    : "PosterFrameKit is evaluating the candidate plan.",
                isWorking: viewModel.isPosterFrameLoading,
                workingDescription: "PosterFrameKit is selecting a frame",
                isUpdating: viewModel.isUpdatingResults
                    || viewModel.isLoadingCandidatePreview
            )
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                acceptDroppedVideo(from: urls)
            } isTargeted: {
                isDropTargeted = $0
            }
            .contextMenu {
                if viewModel.heroImage != nil {
                    Button(
                        "Save Thumbnail…",
                        systemImage: "square.and.arrow.down",
                        action: saveThumbnail
                    )
                }
            }

            DemoHeroMetricsView(metrics: viewModel.heroMetrics)
        }
        .alert(
            "Unable to Save Thumbnail",
            isPresented: $isShowingSaveError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var heroTitle: String {
        guard !viewModel.isHeroRecommendation,
            let number = viewModel.heroCandidateNumber
        else {
            return "PosterFrameKit"
        }
        return "Candidate \(number) of \(viewModel.candidateFrames.count)"
    }

    private var accessibilityLabel: String {
        viewModel.isHeroRecommendation
            ? "Poster frame selected by PosterFrameKit"
            : "Candidate frame selected in the candidate browser"
    }

    private func saveThumbnail() {
        guard let image = viewModel.heroImage else {
            return
        }

        Task {
            do {
                try await DemoThumbnailExporter.requestSave(
                    image: image,
                    title: heroTitle
                )
            } catch {
                saveErrorMessage = error.localizedDescription
                isShowingSaveError = true
            }
        }
    }

    private func acceptDroppedVideo(from urls: [URL]) -> Bool {
        guard let url = urls.first(where: isMovieURL) else {
            return false
        }
        viewModel.selectVideo(url)
        return true
    }

    private func isMovieURL(_ url: URL) -> Bool {
        guard url.isFileURL,
            let type = UTType(filenameExtension: url.pathExtension)
        else {
            return false
        }
        return type.conforms(to: .movie)
    }
}
