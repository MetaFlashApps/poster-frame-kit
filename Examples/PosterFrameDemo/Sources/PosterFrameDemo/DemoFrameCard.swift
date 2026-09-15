import CoreGraphics
import SwiftUI

struct DemoFrameCard: View {
    @State private var isShowingSaveError = false
    @State private var saveErrorMessage = ""

    let title: String
    let image: CGImage?
    let videoPosition: DemoVideoPosition?
    let processingDuration: Duration?
    let timeUnavailableText: String?
    let accessibilityLabel: String
    let emptyTitle: String
    let emptyDescription: String
    var detailText: String? = nil
    var candidateCaptureDuration: Duration? = nil
    var candidateCaptureHelp =
        "Decodes the configured candidate plan separately for the Vision and hybrid comparison."
    var processingLabel = "Complete Selection"
    var processingHelp = "Includes duration loading, seek/decoding, analysis, and ranking."
    var isWorking = false
    var workingDescription: String? = nil
    var isUpdating = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                DemoFrameSurface(
                    image: image,
                    accessibilityLabel: accessibilityLabel,
                    emptyTitle: emptyTitle,
                    emptyDescription: emptyDescription,
                    isWorking: isWorking,
                    workingDescription: workingDescription
                        ?? "Analysis in progress",
                    isUpdating: isUpdating
                )
                .contextMenu {
                    if image != nil {
                        Button(
                            "Save Thumbnail…",
                            systemImage: "square.and.arrow.down",
                            action: saveThumbnail
                        )
                    }
                }

                if let detailText {
                    Text(detailText)
                        .foregroundStyle(.secondary)
                }

                if let videoPosition {
                    LabeledContent {
                        Text(
                            DemoTimestampFormatter.string(
                                from: videoPosition.timestampSeconds
                            ) ?? "Unavailable"
                        )
                    } label: {
                        Image(systemName: "clock")
                            .accessibilityLabel("Timestamp")
                    }
                    LabeledContent("Video Position") {
                        Text(
                            videoPosition.fraction,
                            format: .percent.precision(.fractionLength(1))
                        )
                    }
                } else if image != nil, let timeUnavailableText {
                    Text(timeUnavailableText)
                        .foregroundStyle(.secondary)
                }

                if let candidateCaptureDuration {
                    LabeledContent {
                        DemoDurationValue(duration: candidateCaptureDuration)
                    } label: {
                        Label("Candidate Capture", systemImage: "film.stack")
                    }
                    .foregroundStyle(.secondary)
                    .help(candidateCaptureHelp)
                }

                if let processingDuration {
                    LabeledContent {
                        DemoDurationValue(duration: processingDuration)
                    } label: {
                        Label(processingLabel, systemImage: "stopwatch")
                    }
                    .foregroundStyle(.secondary)
                    .help(processingHelp)
                }
            }
        } label: {
            Label(title, systemImage: "photo")
                .font(.headline)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .alert(
            "Unable to Save Thumbnail",
            isPresented: $isShowingSaveError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func saveThumbnail() {
        guard let image else {
            return
        }

        Task {
            do {
                try await DemoThumbnailExporter.requestSave(
                    image: image,
                    title: title
                )
            } catch {
                saveErrorMessage = error.localizedDescription
                isShowingSaveError = true
            }
        }
    }
}
