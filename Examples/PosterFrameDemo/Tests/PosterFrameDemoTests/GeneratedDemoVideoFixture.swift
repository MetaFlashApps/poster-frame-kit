@preconcurrency import AVFoundation
import CoreVideo
import Foundation

@testable import PosterFrameDemo

enum GeneratedDemoVideoFixture {
  static func make() async throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "PosterFrameDemo-\(UUID().uuidString).mp4")
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
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )

    guard writer.canAdd(input) else {
      throw DemoFrameError.invalidDuration
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? DemoFrameError.invalidDuration
    }
    writer.startSession(atSourceTime: .zero)

    for frameIndex in 0..<12 {
      while !input.isReadyForMoreMediaData {
        try Task.checkCancellation()
        await Task.yield()
      }
      let pixelBuffer = try frame(
        frameIndex,
        width: width,
        height: height
      )
      guard
        adaptor.append(
          pixelBuffer,
          withPresentationTime: CMTime(
            value: Int64(frameIndex),
            timescale: 6
          )
        )
      else {
        throw writer.error ?? DemoFrameError.invalidDuration
      }
    }

    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw writer.error ?? DemoFrameError.invalidDuration
    }
    return url
  }

  private static func frame(
    _ index: Int,
    width: Int,
    height: Int
  ) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      nil,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw DemoFrameError.invalidDuration
    }
    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard lockStatus == kCVReturnSuccess,
      let address = CVPixelBufferGetBaseAddress(pixelBuffer)
    else {
      throw DemoFrameError.invalidDuration
    }
    defer {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }

    let bytes = address.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    for y in 0..<height {
      let row = bytes.advanced(by: y * bytesPerRow)
      for x in 0..<width {
        let value: UInt8
        switch index {
        case 0..<4:
          value = 0
        case 4..<8:
          value = 128
        default:
          value = (x / 8 + y / 8).isMultiple(of: 2) ? 24 : 235
        }
        let offset = x * 4
        row[offset] = value
        row[offset + 1] = value
        row[offset + 2] = value
        row[offset + 3] = 255
      }
    }
    return pixelBuffer
  }
}
