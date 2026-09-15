import CoreVideo
import Foundation
@preconcurrency import Vision

@available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *)
struct VisionAestheticAnalyzer: AestheticAnalyzing {
  func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> AestheticAnalysis {
    try PosterFrameCancellation.check()

    let request = VNCalculateImageAestheticsScoresRequest()
    request.revision = VNCalculateImageAestheticsScoresRequestRevision1
    let cancellation = VisionRequestCancellation(request: request)

    return try await PosterFrameCancellation.map {
      try await withTaskCancellationHandler {
        let handler = VNImageRequestHandler(
          cvPixelBuffer: pixelBuffer,
          orientation: .up
        )
        try handler.perform([request])
        try PosterFrameCancellation.check()
        guard let observation = request.results?.first else {
          throw PosterFrameError.imageCreationFailed
        }
        return AestheticAnalysis(
          score: Double(observation.overallScore),
          isUtilityFrame: observation.isUtility
        )
      } onCancel: {
        cancellation.cancel()
      }
    }
  }
}
