import CoreVideo
import Foundation
@preconcurrency import Vision

package struct VisionSubtitleAnalyzer: SubtitleAnalyzing {
  private static let regionOfInterest = CGRect(
    x: 0,
    y: 0,
    width: 1,
    height: 1.0 / 3.0
  )

  package func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> SubtitleAnalysis {
    let fastRegions = try await recognizedRegions(
      in: pixelBuffer,
      level: .fast
    )
    let fastLikelihood = SubtitleRegionScorer.likelihood(for: fastRegions)
    if fastLikelihood > 0 {
      return SubtitleAnalysis(
        likelihood: fastLikelihood,
        usedAccurateRecognition: false
      )
    }

    var heuristic = SubtitleBandHeuristic()
    guard try heuristic.isSuspicious(pixelBuffer) else {
      return .none
    }

    let accurateRegions = try await recognizedRegions(
      in: pixelBuffer,
      level: .accurate
    )
    return SubtitleAnalysis(
      likelihood: SubtitleRegionScorer.likelihood(for: accurateRegions),
      usedAccurateRecognition: true
    )
  }

  package init() {}

  package func analyzeAccurately(
    _ pixelBuffer: CVPixelBuffer
  ) async throws -> SubtitleAnalysis {
    let regions = try await recognizedRegions(
      in: pixelBuffer,
      level: .accurate
    )
    return SubtitleAnalysis(
      likelihood: SubtitleRegionScorer.likelihood(for: regions),
      usedAccurateRecognition: true
    )
  }

  private func recognizedRegions(
    in pixelBuffer: CVPixelBuffer,
    level: VNRequestTextRecognitionLevel
  ) async throws -> [CGRect] {
    try PosterFrameCancellation.check()

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level
    request.usesLanguageCorrection = false
    request.regionOfInterest = Self.regionOfInterest
    let cancellation = VisionRequestCancellation(request: request)

    return try await PosterFrameCancellation.map {
      try await withTaskCancellationHandler {
        let handler = VNImageRequestHandler(
          cvPixelBuffer: pixelBuffer,
          orientation: .up
        )
        try handler.perform([request])
        try PosterFrameCancellation.check()
        return (request.results ?? []).compactMap { observation in
          guard let candidate = observation.topCandidates(1).first,
            candidate.string.unicodeScalars.count(where: {
              CharacterSet.alphanumerics.contains($0)
            }) >= 2
          else {
            return nil
          }
          return observation.boundingBox
        }
      } onCancel: {
        cancellation.cancel()
      }
    }
  }
}
