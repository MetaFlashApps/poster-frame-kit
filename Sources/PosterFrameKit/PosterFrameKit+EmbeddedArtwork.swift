import CoreGraphics
import Foundation

extension PosterFrameKit {
  /// Loads the first decodable artwork image embedded in a local media file.
  ///
  /// This lookup reads AVFoundation's common artwork metadata and does not
  /// decode, sample, analyze, or rank video frames. It returns `nil` when the
  /// asset contains no artwork or every artwork item contains unsupported or
  /// invalid image data. Call ``bestFrame(in:options:)`` explicitly when a
  /// generated poster frame should be used as the fallback.
  ///
  /// - Parameter url: Local media URL supported by AVFoundation.
  /// - Returns: The first decodable embedded artwork image, or `nil` when none
  ///   is available.
  /// - Throws: ``PosterFrameError/cancelled`` on task cancellation, or an
  ///   AVFoundation metadata-loading error.
  public static func embeddedArtwork(in url: URL) async throws -> CGImage? {
    try await AVFoundationEmbeddedArtworkLoader.load(from: url)
  }
}
