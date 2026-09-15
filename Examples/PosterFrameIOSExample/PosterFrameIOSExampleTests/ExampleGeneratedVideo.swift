@preconcurrency import AVFoundation
import CoreVideo
import Foundation

enum ExampleGeneratedVideo {
  static func make() async throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "PosterFrameIOSExample-\(UUID().uuidString).mp4")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let width = 160
    let height = 90
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
    )
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )

    guard writer.canAdd(input) else {
      throw writer.error ?? CocoaError(.fileWriteUnknown)
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? CocoaError(.fileWriteUnknown)
    }
    writer.startSession(atSourceTime: .zero)

    for frameIndex in 0..<12 {
      while !input.isReadyForMoreMediaData {
        try Task.checkCancellation()
        await Task.yield()
      }
      let buffer = try frame(
        frameIndex,
        width: width,
        height: height
      )
      let presentationTime = CMTime(
        value: Int64(frameIndex),
        timescale: 6
      )
      guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
        throw writer.error ?? CocoaError(.fileWriteUnknown)
      }
    }

    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw writer.error ?? CocoaError(.fileWriteUnknown)
    }
    return url
  }

  private static func frame(
    _ index: Int,
    width: Int,
    height: Int
  ) throws -> CVPixelBuffer {
    try ExamplePixelBufferFactory.bgra(
      width: width,
      height: height
    ) { x, y in
      switch index {
      case 0..<4:
        (blue: 0, green: 0, red: 0)
      case 4..<8:
        (blue: 128, green: 128, red: 128)
      default:
        (x / 8 + y / 8).isMultiple(of: 2)
          ? (blue: 24, green: 24, red: 24)
          : (blue: 235, green: 235, red: 235)
      }
    }
  }
}
