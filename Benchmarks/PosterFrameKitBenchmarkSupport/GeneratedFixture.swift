@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreText
import CoreVideo
import Foundation

package enum GeneratedFixtureVariant: String, CaseIterable, Hashable, Sendable {
  case standard
  case subtitles
  case veryShortSingleScene = "very-short-single-scene"
  case veryShortMultiScene = "very-short-multi-scene"
  case coarseTimestamps = "coarse-timestamps"

  package var identifier: String {
    definition.identifier
  }

  package var definition: GeneratedFixtureDefinition {
    switch self {
    case .standard:
      GeneratedFixtureDefinition(
        identifier: "generated-h264-1280x720-30s-v1",
        version: 1,
        width: 1_280,
        height: 720,
        framesPerSecond: 12,
        durationSeconds: 30,
        maximumKeyFrameInterval: 24,
        sceneDurationSeconds: 5,
        sceneIdentifiers: [0, 1, 2, 3, 4, 5],
        textSegments: []
      )
    case .subtitles:
      GeneratedFixtureDefinition(
        identifier: "generated-h264-1280x720-30s-subtitle-calibration-v3",
        version: 3,
        width: 1_280,
        height: 720,
        framesPerSecond: 12,
        durationSeconds: 30,
        maximumKeyFrameInterval: 24,
        sceneDurationSeconds: 5,
        sceneIdentifiers: [0, 1, 2, 3, 4, 5],
        textSegments: [
          GeneratedFixtureTextSegment(
            startFrame: 9 * 12,
            endFrame: 10 * 12,
            overlay: .dialogueSubtitle
          ),
          GeneratedFixtureTextSegment(
            startFrame: 14 * 12,
            endFrame: 15 * 12,
            overlay: .credits
          ),
          GeneratedFixtureTextSegment(
            startFrame: 19 * 12,
            endFrame: 20 * 12,
            overlay: .sceneSign
          ),
        ]
      )
    case .veryShortSingleScene:
      GeneratedFixtureDefinition(
        identifier: "generated-h264-640x360-1s-single-v1",
        version: 1,
        width: 640,
        height: 360,
        framesPerSecond: 12,
        durationSeconds: 1,
        maximumKeyFrameInterval: 12,
        sceneDurationSeconds: 1,
        sceneIdentifiers: [4],
        textSegments: []
      )
    case .veryShortMultiScene:
      GeneratedFixtureDefinition(
        identifier: "generated-h264-640x360-3s-multi-v1",
        version: 1,
        width: 640,
        height: 360,
        framesPerSecond: 12,
        durationSeconds: 3,
        maximumKeyFrameInterval: 36,
        sceneDurationSeconds: 1,
        sceneIdentifiers: [0, 4, 5],
        textSegments: []
      )
    case .coarseTimestamps:
      GeneratedFixtureDefinition(
        identifier: "generated-h264-640x360-8s-2fps-long-gop-v1",
        version: 1,
        width: 640,
        height: 360,
        framesPerSecond: 2,
        durationSeconds: 8,
        maximumKeyFrameInterval: 16,
        sceneDurationSeconds: 2,
        sceneIdentifiers: [0, 2, 4, 5],
        textSegments: []
      )
    }
  }
}

package struct GeneratedFixtureDefinition: Equatable, Sendable {
  package let identifier: String
  package let version: Int
  package let width: Int
  package let height: Int
  package let framesPerSecond: Int
  package let durationSeconds: Int
  package let maximumKeyFrameInterval: Int
  package let sceneDurationSeconds: Int
  package let sceneIdentifiers: [Int]
  package let textSegments: [GeneratedFixtureTextSegment]

  package var frameCount: Int {
    durationSeconds * framesPerSecond
  }
}

package struct GeneratedFixtureTextSegment: Equatable, Sendable {
  package let startFrame: Int
  package let endFrame: Int
  package let overlay: GeneratedFixtureTextOverlay

  package func contains(_ frameIndex: Int) -> Bool {
    startFrame <= frameIndex && frameIndex < endFrame
  }
}

package enum GeneratedFixtureTextOverlay: Hashable, Sendable {
  case dialogueSubtitle
  case credits
  case sceneSign
}

package enum GeneratedFixture {
  package static let generatorName = "poster-frame-kit-synthetic-video"

  package static func url(for variant: GeneratedFixtureVariant) -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appending(path: ".build/poster-frame-benchmarks")
      .appending(path: "\(variant.definition.identifier).mp4")
  }

  package static func makeIfNeeded(
    at url: URL,
    variant: GeneratedFixtureVariant
  ) async throws {
    let definition = variant.definition
    if FileManager.default.fileExists(atPath: url.path),
      try await isUsable(url, definition: definition)
    {
      return
    }

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: definition.width,
        AVVideoHeightKey: definition.height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: 4_000_000,
          AVVideoMaxKeyFrameIntervalKey: definition.maximumKeyFrameInterval,
        ],
      ]
    )
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: definition.width,
        kCVPixelBufferHeightKey as String: definition.height,
      ]
    )
    guard writer.canAdd(input) else {
      throw GeneratedFixtureError.creationFailed(
        "AVAssetWriter rejected its video input."
      )
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw GeneratedFixtureError.creationFailed(
        writer.error?.localizedDescription ?? "Writer failed."
      )
    }
    writer.startSession(atSourceTime: .zero)

    var scenes: [Int: CVPixelBuffer] = [:]
    for sceneIdentifier in Set(definition.sceneIdentifiers) {
      scenes[sceneIdentifier] = try makeScene(
        sceneIdentifier,
        width: definition.width,
        height: definition.height,
        overlay: nil
      )
    }
    var overlayScenes: [OverlaySceneKey: CVPixelBuffer] = [:]
    for segment in definition.textSegments {
      for frameIndex in segment.startFrame..<segment.endFrame {
        let sceneIdentifier = sceneIdentifier(
          at: frameIndex,
          definition: definition
        )
        let key = OverlaySceneKey(
          sceneIdentifier: sceneIdentifier,
          overlay: segment.overlay
        )
        if overlayScenes[key] == nil {
          overlayScenes[key] = try makeScene(
            sceneIdentifier,
            width: definition.width,
            height: definition.height,
            overlay: segment.overlay
          )
        }
      }
    }

    for frameIndex in 0..<definition.frameCount {
      try Task.checkCancellation()
      while !input.isReadyForMoreMediaData {
        try Task.checkCancellation()
        await Task.yield()
      }
      let sceneIdentifier = sceneIdentifier(
        at: frameIndex,
        definition: definition
      )
      let overlay = definition.textSegments.first {
        $0.contains(frameIndex)
      }?.overlay
      let frame = overlay.flatMap {
        overlayScenes[
          OverlaySceneKey(sceneIdentifier: sceneIdentifier, overlay: $0)
        ]
      } ?? scenes[sceneIdentifier]
      guard let frame else {
        throw GeneratedFixtureError.creationFailed(
          "The generated scene buffer is unavailable."
        )
      }
      let time = CMTime(
        value: Int64(frameIndex),
        timescale: Int32(definition.framesPerSecond)
      )
      guard adaptor.append(frame, withPresentationTime: time) else {
        throw GeneratedFixtureError.creationFailed(
          writer.error?.localizedDescription
            ?? "Appending a fixture frame failed."
        )
      }
    }

    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw GeneratedFixtureError.creationFailed(
        writer.error?.localizedDescription ?? "Finishing the fixture failed."
      )
    }
  }

  private static func isUsable(
    _ url: URL,
    definition: GeneratedFixtureDefinition
  ) async throws -> Bool {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration).seconds
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = tracks.first else {
      return false
    }
    let size = try await track.load(.naturalSize)
    return abs(duration - Double(definition.durationSeconds)) <= 0.2
      && Int(abs(size.width)) == definition.width
      && Int(abs(size.height)) == definition.height
  }

  private static func sceneIdentifier(
    at frameIndex: Int,
    definition: GeneratedFixtureDefinition
  ) -> Int {
    let framesPerScene = max(
      definition.framesPerSecond * definition.sceneDurationSeconds,
      1
    )
    let sceneIndex = min(
      frameIndex / framesPerScene,
      definition.sceneIdentifiers.count - 1
    )
    return definition.sceneIdentifiers[sceneIndex]
  }

  private static func makeScene(
    _ scene: Int,
    width: Int,
    height: Int,
    overlay: GeneratedFixtureTextOverlay?
  ) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      ] as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw GeneratedFixtureError.creationFailed(
        "Creating a fixture pixel buffer failed."
      )
    }
    guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess,
      let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    else {
      throw GeneratedFixtureError.creationFailed(
        "Locking a fixture pixel buffer failed."
      )
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    for y in 0..<height {
      let row = bytes.advanced(by: y * bytesPerRow)
      for x in 0..<width {
        let pixel = row.advanced(by: x * 4)
        let color = sceneColor(
          scene: scene,
          x: x,
          y: y,
          width: width,
          height: height
        )
        pixel[0] = color.blue
        pixel[1] = color.green
        pixel[2] = color.red
        pixel[3] = 255
      }
    }
    if let overlay {
      try drawTextOverlay(
        overlay,
        in: pixelBuffer,
        baseAddress: baseAddress,
        width: width,
        height: height
      )
    }
    return pixelBuffer
  }

  private static func drawTextOverlay(
    _ overlay: GeneratedFixtureTextOverlay,
    in pixelBuffer: CVPixelBuffer,
    baseAddress: UnsafeMutableRawPointer,
    width: Int,
    height: Int
  ) throws {
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue
      | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let context = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else {
      throw GeneratedFixtureError.creationFailed(
        "Creating a subtitle drawing context failed."
      )
    }

    switch overlay {
    case .dialogueSubtitle:
      drawTextLines(
        ["We should take the northern path."],
        fontSize: 54,
        baselineY: max(CGFloat(height) * 0.09, 16),
        lineSpacing: 66,
        in: context,
        width: width,
        outlined: true
      )
    case .credits:
      drawTextLines(
        ["DIRECTED BY", "POSTER FRAME"],
        fontSize: 42,
        baselineY: max(CGFloat(height) * 0.07, 14),
        lineSpacing: 54,
        in: context,
        width: width,
        outlined: false
      )
    case .sceneSign:
      let signRect = CGRect(
        x: CGFloat(width) * 0.27,
        y: CGFloat(height) * 0.48,
        width: CGFloat(width) * 0.46,
        height: CGFloat(height) * 0.18
      )
      context.setFillColor(CGColor(gray: 0.12, alpha: 0.92))
      context.fill(signRect)
      context.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
      context.setLineWidth(5)
      context.stroke(signRect)
      drawTextLines(
        ["OLD TOWN STATION"],
        fontSize: 48,
        baselineY: signRect.midY - 18,
        lineSpacing: 60,
        in: context,
        width: width,
        outlined: false
      )
    }
  }

  private static func drawTextLines(
    _ strings: [String],
    fontSize: CGFloat,
    baselineY: CGFloat,
    lineSpacing: CGFloat,
    in context: CGContext,
    width: Int,
    outlined: Bool
  ) {
    let font = CTFontCreateWithName(
      "Helvetica Bold" as CFString,
      fontSize,
      nil
    )
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String):
        CGColor(gray: 1, alpha: 1),
      NSAttributedString.Key(kCTStrokeColorAttributeName as String):
        CGColor(gray: 0, alpha: 1),
      NSAttributedString.Key(kCTStrokeWidthAttributeName as String):
        outlined ? -5 : 0,
    ]
    for (index, string) in strings.enumerated() {
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(
          string: string,
          attributes: attributes
        )
      )
      let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
      context.textPosition = CGPoint(
        x: (CGFloat(width) - lineWidth) / 2,
        y: baselineY + CGFloat(index) * lineSpacing
      )
      CTLineDraw(line, context)
    }
  }

  private static func sceneColor(
    scene: Int,
    x: Int,
    y: Int,
    width: Int,
    height: Int
  ) -> (blue: UInt8, green: UInt8, red: UInt8) {
    switch scene {
    case 0:
      return (4, 4, 4)
    case 1:
      let value = UInt8(x * 180 / max(width - 1, 1) + 32)
      return (value, value, value)
    case 2:
      let band = x * 6 / width
      let colors: [(UInt8, UInt8, UInt8)] = [
        (32, 32, 220), (32, 200, 220), (32, 190, 32),
        (210, 180, 32), (210, 32, 160), (180, 32, 32),
      ]
      let color = colors[min(band, colors.count - 1)]
      return (color.0, color.1, color.2)
    case 3:
      let value: UInt8 = ((x / 32) + (y / 32)).isMultiple(of: 2) ? 30 : 225
      return (value, value, value)
    case 4:
      let sky = y < height / 2
      return sky ? (210, 155, 70) : (55, 115, 210)
    default:
      let ring =
        ((x - width / 2) * (x - width / 2)
          + (y - height / 2) * (y - height / 2)) / 2_500
      return ring.isMultiple(of: 2) ? (48, 210, 245) : (205, 64, 92)
    }
  }
}

private struct OverlaySceneKey: Hashable {
  let sceneIdentifier: Int
  let overlay: GeneratedFixtureTextOverlay
}

package enum GeneratedFixtureError: LocalizedError {
  case creationFailed(String)

  package var errorDescription: String? {
    switch self {
    case .creationFailed(let message):
      message
    }
  }
}
