import CoreGraphics
import CoreMedia
import Foundation
import Observation
import PosterFrameKit

@MainActor
@Observable
final class DemoViewModel {
    var selectedURL: URL?
    var baselineFrame: BaselineFrame?
    var selectionResult: PosterFrameResult?
    var posterFrameDuration: Duration?
    var comparisonCaptureDuration: Duration?
    var visionResult: DemoComparisonResult?
    var hybridResult: DemoComparisonResult?
    var visionDuration: Duration?
    var visionErrorMessage: String?
    var appliedOptions: PosterFrameOptions?
    var candidateFrames: [DemoCandidateFrame] = []
    var browsedCandidateID: DemoCandidateFrame.ID?
    var browsedCandidateImage: CGImage?
    var excludesMidroll = true
    var avoidsSubtitles = false
    var prefersFaces = false
    var prefersAesthetics = false
    var profile = DemoProfile.animation
    var maximumFramesExamined = 24
    var isLoadingBaseline = false
    var isAnalyzing = false
    var isAutoRunPending = false
    var isLoadingCandidatePreview = false
    var analysisStage: DemoAnalysisStage?
    var isShowingError = false
    var errorMessage: String?
    @ObservationIgnored
    private var baselineTask: Task<Void, Never>?

    @ObservationIgnored
    private var analysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var scheduledAnalysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var candidatePreviewTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeAnalysisID: UUID?

    var selectedFileName: String? {
        selectedURL?.lastPathComponent
    }

    var selectedVideoDurationText: String? {
        guard let seconds = baselineFrame?.duration.seconds else {
            return nil
        }
        return DemoTimestampFormatter.string(from: seconds)
    }

    var performanceComparison: DemoPerformanceComparison? {
        guard let posterFrameDuration,
            let comparisonCaptureDuration,
            let visionDuration
        else {
            return nil
        }
        return DemoPerformanceComparison(
            posterFrameDuration: posterFrameDuration,
            candidateCaptureDuration: comparisonCaptureDuration,
            visionRankingDuration: visionDuration
        )
    }

    var options: PosterFrameOptions {
        PosterFrameOptions(
            maximumFramesExamined: maximumFramesExamined,
            excludedRanges: excludesMidroll ? [0.46...0.54] : [],
            profile: profile.posterFrameProfile,
            subtitleAvoidance: avoidsSubtitles
                ? PosterFrameSubtitleOptions()
                : nil,
            facePreference: prefersFaces
                ? PosterFrameFaceOptions()
                : nil,
            aestheticPreference: prefersAesthetics
                ? PosterFrameAestheticOptions()
                : nil,
            outputSize: CGSize(width: 1_280, height: 720)
        )
    }

    var comparisonCaptureOptions: PosterFrameOptions {
        var options = options
        // Capture retains every candidate, so winner refinement would add work
        // without changing the comparison set.
        options.subtitleAvoidance = nil
        options.facePreference = nil
        options.aestheticPreference = nil
        return options
    }

    var canRunAnalysis: Bool {
        selectedURL != nil
            && !isLoadingBaseline
            && !isAnalyzing
            && !isAutoRunPending
    }

    var hasPendingOptionChanges: Bool {
        guard let appliedOptions else {
            return false
        }
        return appliedOptions != options
    }

    var isPosterFrameLoading: Bool {
        isAnalyzing && selectionResult == nil
    }

    var isUpdatingResults: Bool {
        selectionResult != nil && (isAnalyzing || isAutoRunPending)
    }

    var isVisionComparisonLoading: Bool {
        isAnalyzing
            && isVisionAvailable
            && visionResult == nil
            && visionErrorMessage == nil
    }

    var browsedCandidate: DemoCandidateFrame? {
        guard let browsedCandidateID else {
            return nil
        }
        return candidateFrames.first { $0.id == browsedCandidateID }
    }

    var officialCandidateID: DemoCandidateFrame.ID? {
        guard let selectionTime = selectionResult?.time else {
            return nil
        }
        return candidateFrames.first {
            CMTimeCompare($0.time, selectionTime) == 0
        }?.id
    }

    var heroImage: CGImage? {
        guard let browsedCandidate else {
            return selectionResult?.image
        }
        if browsedCandidate.id == officialCandidateID {
            return selectionResult?.image ?? browsedCandidate.thumbnail
        }
        return browsedCandidateImage ?? browsedCandidate.thumbnail
    }

    var heroTime: CMTime? {
        browsedCandidate?.time ?? selectionResult?.time
    }

    var heroScore: Double? {
        guard let browsedCandidate else {
            return selectionResult?.adjustedScore
        }
        if browsedCandidate.id == officialCandidateID {
            return selectionResult?.adjustedScore ?? browsedCandidate.baseScore
        }
        return browsedCandidate.baseScore
    }

    var heroMetrics: FrameMetrics? {
        browsedCandidate?.metrics ?? selectionResult?.metrics
    }

    var isHeroRecommendation: Bool {
        browsedCandidate == nil || browsedCandidate?.id == officialCandidateID
    }

    var heroCandidateNumber: Int? {
        guard let browsedCandidateID,
            let index = candidateFrames.firstIndex(where: {
                $0.id == browsedCandidateID
            })
        else {
            return nil
        }
        return index + 1
    }

    var visionWorkingDescription: String {
        switch analysisStage {
        case .posterFrameKit:
            "Waiting for PosterFrameKit…"
        case .comparisonCapture:
            "Capturing comparison candidates…"
        case .vision:
            "Apple Vision is ranking candidates…"
        case nil:
            "Preparing comparison…"
        }
    }

    var isVisionAvailable: Bool {
        if #available(macOS 15.0, *) {
            true
        } else {
            false
        }
    }

    var visionDetailText: String? {
        guard let visionResult else {
            return nil
        }
        let score = visionResult.score.formatted(
            .number
                .sign(strategy: .always())
                .precision(.fractionLength(3))
        )
        let utility = visionResult.isUtility ? "Utility" : "Not utility"
        return "Vision \(score) · \(utility)"
    }

    var hybridDetailText: String? {
        guard let hybridResult else {
            return nil
        }
        let score = hybridResult.score.formatted(
            .percent.precision(.fractionLength(1))
        )
        return "Hybrid Score \(score)"
    }

    var posterFrameDetailText: String? {
        guard let selectionResult else {
            return nil
        }
        let score = selectionResult.adjustedScore.formatted(
            .percent.precision(.fractionLength(1))
        )
        return "Ranking Score \(score)"
    }

    func videoPosition(for time: CMTime?) -> DemoVideoPosition? {
        guard let time, let duration = baselineFrame?.duration else {
            return nil
        }
        return DemoVideoPosition(time: time, duration: duration)
    }

    var visionEmptyTitle: String {
        if selectedURL == nil {
            "No Video Selected"
        } else if !isVisionAvailable {
            "Vision Unavailable"
        } else if visionErrorMessage != nil {
            "Vision Failed"
        } else {
            "Not Compared Yet"
        }
    }

    var visionEmptyDescription: String {
        if selectedURL == nil {
            "Choose a video."
        } else if !isVisionAvailable {
            "Apple Image Aesthetics requires macOS 15 or newer."
        } else if let visionErrorMessage {
            visionErrorMessage
        } else {
            "The automatic comparison has not produced a Vision result yet."
        }
    }

    func selectVideo(_ url: URL) {
        baselineTask?.cancel()
        analysisTask?.cancel()
        scheduledAnalysisTask?.cancel()
        candidatePreviewTask?.cancel()
        activeAnalysisID = nil
        selectedURL = url
        baselineFrame = nil
        clearComparison()
        isLoadingBaseline = true
        isAnalyzing = false
        isAutoRunPending = false
        isLoadingCandidatePreview = false
        analysisStage = nil

        baselineTask = Task { [weak self] in
            guard let self else {
                return
            }

            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let frame = try await BaselineFrameLoader.load(from: url)
                try Task.checkCancellation()
                baselineFrame = frame
                isLoadingBaseline = false
            } catch is CancellationError {
                return
            } catch {
                isLoadingBaseline = false
                present(error)
            }
        }

        runComparison()
    }

    func scheduleComparison() {
        guard selectedURL != nil else {
            return
        }

        scheduledAnalysisTask?.cancel()
        analysisTask?.cancel()
        activeAnalysisID = nil
        analysisTask = nil
        isAnalyzing = false
        analysisStage = nil
        isAutoRunPending = true

        scheduledAnalysisTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                try Task.checkCancellation()
            } catch {
                return
            }
            guard let self else {
                return
            }
            scheduledAnalysisTask = nil
            isAutoRunPending = false
            runComparison()
        }
    }

    func runComparison() {
        guard let selectedURL else {
            return
        }

        scheduledAnalysisTask?.cancel()
        scheduledAnalysisTask = nil
        analysisTask?.cancel()
        candidatePreviewTask?.cancel()
        candidatePreviewTask = nil
        isLoadingCandidatePreview = false
        let analysisID = UUID()
        activeAnalysisID = analysisID
        isAutoRunPending = false
        isAnalyzing = true
        analysisStage = .posterFrameKit
        visionErrorMessage = nil
        let options = options
        let captureOptions = comparisonCaptureOptions

        analysisTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                if activeAnalysisID == analysisID {
                    isAnalyzing = false
                    analysisStage = nil
                    analysisTask = nil
                    activeAnalysisID = nil
                }
            }

            let hasSecurityScope = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let output = try await DemoAnalysisCoordinator.run(
                    videoURL: selectedURL,
                    options: options,
                    comparisonCaptureOptions: captureOptions
                ) { [weak self] progress in
                    guard let self, activeAnalysisID == analysisID else {
                        return
                    }
                    switch progress {
                    case .selected(let result, let duration):
                        posterFrameDuration = duration
                        selectionResult = result
                        appliedOptions = options
                        browsedCandidateID = nil
                        browsedCandidateImage = nil
                    case .stage(let stage):
                        analysisStage = stage
                    }
                }
                try Task.checkCancellation()
                guard activeAnalysisID == analysisID else {
                    return
                }
                apply(output)
            } catch is CancellationError {
                return
            } catch PosterFrameError.cancelled {
                return
            } catch {
                guard activeAnalysisID == analysisID else {
                    return
                }
                present(error)
            }
        }
    }

    func browseCandidate(_ id: DemoCandidateFrame.ID) {
        guard let candidate = candidateFrames.first(where: { $0.id == id }) else {
            return
        }

        candidatePreviewTask?.cancel()
        browsedCandidateID = id
        browsedCandidateImage = nil
        isLoadingCandidatePreview = false

        guard id != officialCandidateID, let selectedURL else {
            return
        }

        isLoadingCandidatePreview = true
        candidatePreviewTask = Task { [weak self] in
            guard let self else {
                return
            }
            let hasSecurityScope = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let image = try await DemoCandidatePreviewLoader.load(
                    from: selectedURL,
                    at: candidate.time,
                    maximumSize: options.outputSize ?? CGSize(width: 1_280, height: 720)
                )
                try Task.checkCancellation()
                guard browsedCandidateID == id else {
                    return
                }
                browsedCandidateImage = image
                isLoadingCandidatePreview = false
                candidatePreviewTask = nil
            } catch is CancellationError {
                return
            } catch PosterFrameError.cancelled {
                return
            } catch {
                guard browsedCandidateID == id else {
                    return
                }
                isLoadingCandidatePreview = false
                candidatePreviewTask = nil
                present(message: "Candidate preview failed: \(error.localizedDescription)")
            }
        }
    }

    func cancelAnalysis() {
        scheduledAnalysisTask?.cancel()
        scheduledAnalysisTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        activeAnalysisID = nil
        isAnalyzing = false
        isAutoRunPending = false
        analysisStage = nil
    }

    func present(_ error: any Error) {
        present(message: error.localizedDescription)
    }

    func present(message: String) {
        errorMessage = message
        isShowingError = true
    }

    func dismissError() {
        isShowingError = false
        errorMessage = nil
    }

    private func clearComparison() {
        selectionResult = nil
        posterFrameDuration = nil
        comparisonCaptureDuration = nil
        visionResult = nil
        hybridResult = nil
        visionDuration = nil
        visionErrorMessage = nil
        appliedOptions = nil
        candidateFrames = []
        browsedCandidateID = nil
        browsedCandidateImage = nil
        isLoadingCandidatePreview = false
    }

    private func selectOfficialCandidate() {
        browsedCandidateID = officialCandidateID
        browsedCandidateImage = nil
    }

    private func apply(_ output: DemoAnalysisOutput) {
        comparisonCaptureDuration = output.comparisonCaptureDuration
        visionDuration = output.visionDuration
        candidateFrames = output.candidateFrames
        visionResult = output.visionResult
        hybridResult = output.hybridResult
        visionErrorMessage = output.comparisonErrorMessage
        browsedCandidateID = nil
        browsedCandidateImage = nil
        selectOfficialCandidate()
    }
}
