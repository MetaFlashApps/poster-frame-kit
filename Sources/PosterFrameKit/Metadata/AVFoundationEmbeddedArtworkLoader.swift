@preconcurrency import AVFoundation
import CoreGraphics
import ImageIO

enum AVFoundationEmbeddedArtworkLoader {
  static func load(from url: URL) async throws -> CGImage? {
    try PosterFrameCancellation.check()

    let asset = AVURLAsset(url: url)
    let metadata = try await PosterFrameCancellation.map {
      try await asset.load(.commonMetadata)
    }
    let artworkItems = AVMetadataItem.metadataItems(
      from: metadata,
      filteredByIdentifier: .commonIdentifierArtwork
    )

    for artworkItem in artworkItems {
      try PosterFrameCancellation.check()
      guard let data = try await PosterFrameCancellation.map({
        try await artworkItem.load(.dataValue)
      }), !data.isEmpty,
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        CGImageSourceGetCount(source) > 0,
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else {
        continue
      }
      try PosterFrameCancellation.check()
      return image
    }

    return nil
  }
}
