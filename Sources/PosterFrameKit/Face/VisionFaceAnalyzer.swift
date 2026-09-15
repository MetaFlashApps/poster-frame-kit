import CoreVideo
import Foundation
@preconcurrency import Vision

package struct VisionFaceAnalyzer: FaceAnalyzing {
  package init() {}

  package func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> FaceAnalysis {
    try PosterFrameCancellation.check()

    let request = VNDetectFaceRectanglesRequest()
    request.revision = VNDetectFaceRectanglesRequestRevision3
    let cancellation = VisionRequestCancellation(request: request)

    return try await PosterFrameCancellation.map {
      try await withTaskCancellationHandler {
        let handler = VNImageRequestHandler(
          cvPixelBuffer: pixelBuffer,
          orientation: .up
        )
        try handler.perform([request])
        try PosterFrameCancellation.check()
        let observations = request.results ?? []
        return FaceAnalysis(
          faceBounds: observations.map(\.boundingBox),
          faceConfidences: observations.map(\.confidence)
        )
      } onCancel: {
        cancellation.cancel()
      }
    }
  }
}
