import CoreVideo
import Foundation

enum ExamplePixelBufferFactory {
  static func bgra(
    width: Int,
    height: Int,
    pixel: (_ x: Int, _ y: Int) -> (blue: UInt8, green: UInt8, red: UInt8)
  ) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw NSError(
        domain: "PosterFrameIOSExample.PixelBuffer",
        code: Int(status)
      )
    }

    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard lockStatus == kCVReturnSuccess else {
      throw NSError(
        domain: "PosterFrameIOSExample.PixelBufferLock",
        code: Int(lockStatus)
      )
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw NSError(
        domain: "PosterFrameIOSExample.PixelBufferBaseAddress",
        code: -1
      )
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    for y in 0..<height {
      let row = baseAddress
        .advanced(by: y * bytesPerRow)
        .assumingMemoryBound(to: UInt8.self)
      for x in 0..<width {
        let color = pixel(x, y)
        let offset = x * 4
        row[offset] = color.blue
        row[offset + 1] = color.green
        row[offset + 2] = color.red
        row[offset + 3] = 255
      }
    }
    return pixelBuffer
  }
}
