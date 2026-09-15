@preconcurrency import AVFoundation
import CoreGraphics
import CoreVideo

/// An actor-isolated frame source backed by AVFoundation.
///
/// The source applies the video's preferred track transform and uses exact
/// timestamp tolerances. Containers and codecs are limited to those supported
/// by AVFoundation on the current operating system.
public actor AVFoundationFrameSource: PosterFrameSource {
  private let asset: AVURLAsset
  private let generator: AVAssetImageGenerator
  private let performanceRecorder: PosterFramePerformanceRecorder?
  private var cachedDuration: CMTime?

  /// Creates a source for a local video URL.
  ///
  /// - Parameter url: URL of an AVFoundation-compatible local video.
  public init(url: URL) {
    self.init(
      asset: AVURLAsset(url: url),
      performanceRecorder: nil
    )
  }

  package init(
    asset: AVURLAsset,
    knownDuration: CMTime? = nil,
    performanceRecorder: PosterFramePerformanceRecorder?
  ) {
    self.asset = asset
    self.cachedDuration = knownDuration
    self.performanceRecorder = performanceRecorder

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    self.generator = generator
  }

  /// The finite, positive asset duration.
  ///
  /// - Throws: ``PosterFrameError/noVideoTrack`` when the asset contains no
  ///   video track, ``PosterFrameError/invalidDuration`` for an unusable
  ///   duration, ``PosterFrameError/cancelled`` on task cancellation, or an
  ///   AVFoundation metadata error.
  public var duration: CMTime {
    get async throws {
      if let cachedDuration {
        return cachedDuration
      }

      try PosterFrameCancellation.check()
      let start = ContinuousClock.now
      let tracks = try await asset.loadTracks(withMediaType: .video)
      guard !tracks.isEmpty else {
        throw PosterFrameError.noVideoTrack
      }

      let duration = try await asset.load(.duration)
      let durationInSeconds = duration.seconds
      guard duration.isValid,
        duration.isNumeric,
        durationInSeconds.isFinite,
        durationInSeconds > 0
      else {
        throw PosterFrameError.invalidDuration
      }

      cachedDuration = duration
      if let performanceRecorder {
        await performanceRecorder.recordMetadata(start.duration(to: .now))
      }
      return duration
    }
  }

  /// Decodes a display-oriented BGRA frame with its actual timestamp.
  ///
  /// - Parameters:
  ///   - time: Requested timestamp. Values outside the asset are clamped to a
  ///     decodable boundary.
  ///   - maximumSize: Optional maximum pixel bounds that preserve aspect
  ///     ratio.
  /// - Returns: A display-oriented sample with requested and actual times.
  /// - Throws: ``PosterFrameError`` or an AVFoundation decoding error.
  public func frame(
    at time: CMTime,
    maximumSize: CGSize?
  ) async throws -> PosterFrameSample {
    let duration = try await duration
    try PosterFrameCancellation.check()

    generator.maximumSize = maximumSize ?? .zero
    let decodeStart = ContinuousClock.now
    if let performanceRecorder {
      await performanceRecorder.decodeStarted()
    }
    let generated: (image: CGImage, actualTime: CMTime)
    do {
      generated = try await generator.image(
        at: Self.generationTime(for: time, duration: duration)
      )
    } catch {
      if let performanceRecorder {
        await performanceRecorder.decodeFinished(
          after: decodeStart.duration(to: .now)
        )
      }
      throw error
    }
    if let performanceRecorder {
      await performanceRecorder.decodeFinished(after: decodeStart.duration(to: .now))
    }
    try PosterFrameCancellation.check()

    let conversionStart = ContinuousClock.now
    let converted = try await Self.pixelBuffer(
      from: SendableImage(image: generated.image)
    )
    if let performanceRecorder {
      await performanceRecorder.recordImageConversion(
        conversionStart.duration(to: .now)
      )
    }
    return PosterFrameSample(
      pixelBuffer: converted.pixelBuffer,
      requestedTime: time,
      actualTime: generated.actualTime
    )
  }

  private static func generationTime(for requestedTime: CMTime, duration: CMTime) -> CMTime {
    if CMTimeCompare(requestedTime, .zero) < 0 {
      return .zero
    }
    guard CMTimeCompare(requestedTime, duration) >= 0 else {
      return requestedTime
    }

    let timescale = max(duration.timescale, 600)
    let lastDecodableTime = CMTimeSubtract(
      duration,
      CMTime(value: 1, timescale: timescale)
    )
    return CMTimeCompare(lastDecodableTime, .zero) > 0
      ? lastDecodableTime
      : .zero
  }

  private nonisolated static func pixelBuffer(
    from sendableImage: SendableImage
  ) async throws -> SendablePixelBuffer {
    let image = sendableImage.image
    var pixelBuffer: CVPixelBuffer?
    let attributes: CFDictionary =
      [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      ] as CFDictionary
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      image.width,
      image.height,
      kCVPixelFormatType_32BGRA,
      attributes,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw PosterFrameError.imageCreationFailed
    }

    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard lockStatus == kCVReturnSuccess else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue
      | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let context = CGContext(
        data: baseAddress,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
    else {
      throw PosterFrameError.imageCreationFailed
    }

    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return SendablePixelBuffer(pixelBuffer: pixelBuffer)
  }
}

private struct SendableImage: @unchecked Sendable {
  let image: CGImage
}

private struct SendablePixelBuffer: @unchecked Sendable {
  let pixelBuffer: CVPixelBuffer
}
