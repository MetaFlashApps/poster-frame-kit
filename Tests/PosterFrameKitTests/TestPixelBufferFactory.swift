import CoreVideo

@testable import PosterFrameKit

enum TestPixelBufferFactory {
  static func bgra(
    width: Int,
    height: Int,
    pixel: (Int, Int) -> (blue: UInt8, green: UInt8, red: UInt8)
  ) throws -> CVPixelBuffer {
    try packed(
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_32BGRA
    ) { row, offset, x, y in
      let value = pixel(x, y)
      row[offset] = value.blue
      row[offset + 1] = value.green
      row[offset + 2] = value.red
      row[offset + 3] = 255
    }
  }

  static func argb(
    width: Int,
    height: Int,
    pixel: (Int, Int) -> (red: UInt8, green: UInt8, blue: UInt8)
  ) throws -> CVPixelBuffer {
    try packed(
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_32ARGB
    ) { row, offset, x, y in
      let value = pixel(x, y)
      row[offset] = 255
      row[offset + 1] = value.red
      row[offset + 2] = value.green
      row[offset + 3] = value.blue
    }
  }

  static func biPlanar420(
    width: Int,
    height: Int,
    videoRange: Bool,
    luma: (Int, Int) -> UInt8,
    chroma: (Int, Int) -> (cb: UInt8, cr: UInt8)
  ) throws -> CVPixelBuffer {
    let buffer = try makeBuffer(
      width: width,
      height: height,
      pixelFormat: videoRange
        ? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    )
    let status = CVPixelBufferLockBaseAddress(buffer, [])
    guard status == kCVReturnSuccess,
      CVPixelBufferGetPlaneCount(buffer) == 2,
      let lumaAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
      let chromaAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
    else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, [])
    }

    let lumaBytes = lumaAddress.assumingMemoryBound(to: UInt8.self)
    let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    for y in 0..<height {
      let row = lumaBytes.advanced(by: y * lumaBytesPerRow)
      for x in 0..<width {
        row[x] = luma(x, y)
      }
    }

    let chromaBytes = chromaAddress.assumingMemoryBound(to: UInt8.self)
    let chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
    let chromaWidth = CVPixelBufferGetWidthOfPlane(buffer, 1)
    let chromaHeight = CVPixelBufferGetHeightOfPlane(buffer, 1)
    for y in 0..<chromaHeight {
      let row = chromaBytes.advanced(by: y * chromaBytesPerRow)
      for x in 0..<chromaWidth {
        let value = chroma(x, y)
        row[x * 2] = value.cb
        row[x * 2 + 1] = value.cr
      }
    }

    return buffer
  }

  private static func packed(
    width: Int,
    height: Int,
    pixelFormat: OSType,
    writePixel: (
      _ row: UnsafeMutablePointer<UInt8>,
      _ offset: Int,
      _ x: Int,
      _ y: Int
    ) -> Void
  ) throws -> CVPixelBuffer {
    let buffer = try makePackedBuffer(
      width: width,
      height: height,
      pixelFormat: pixelFormat
    )
    let status = CVPixelBufferLockBaseAddress(buffer, [])
    guard status == kCVReturnSuccess,
      let baseAddress = CVPixelBufferGetBaseAddress(buffer)
    else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, [])
    }

    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<height {
      let row = bytes.advanced(by: y * bytesPerRow)
      for x in 0..<width {
        writePixel(row, x * 4, x, y)
      }
    }

    return buffer
  }

  private static func makePackedBuffer(
    width: Int,
    height: Int,
    pixelFormat: OSType
  ) throws -> CVPixelBuffer {
    let bytesPerRow = width * 4
    let byteCount = bytesPerRow * height
    let address = UnsafeMutableRawPointer.allocate(
      byteCount: byteCount,
      alignment: 64
    )
    address.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreateWithBytes(
      kCFAllocatorDefault,
      width,
      height,
      pixelFormat,
      address,
      bytesPerRow,
      { _, baseAddress in
        guard let baseAddress else {
          return
        }
        UnsafeMutableRawPointer(mutating: baseAddress).deallocate()
      },
      nil,
      nil,
      &buffer
    )
    guard status == kCVReturnSuccess, let buffer else {
      address.deallocate()
      throw PosterFrameError.invalidPixelBuffer
    }
    return buffer
  }

  static func monochrome(
    width: Int,
    height: Int,
    pixel: (Int, Int) -> UInt8
  ) throws -> CVPixelBuffer {
    let buffer = try makeBuffer(
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_OneComponent8
    )
    let status = CVPixelBufferLockBaseAddress(buffer, [])
    guard status == kCVReturnSuccess,
      let baseAddress = CVPixelBufferGetBaseAddress(buffer)
    else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, [])
    }

    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<height {
      let row = bytes.advanced(by: y * bytesPerRow)
      for x in 0..<width {
        row[x] = pixel(x, y)
      }
    }

    return buffer
  }

  static func unsupported(width: Int, height: Int) throws -> CVPixelBuffer {
    try makeBuffer(
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_422YpCbCr8
    )
  }

  private static func makeBuffer(
    width: Int,
    height: Int,
    pixelFormat: OSType
  ) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let isBiPlanar =
      pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
      || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    let attributes: CFDictionary =
      isBiPlanar
      ? [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary]
        as CFDictionary
      : [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      ] as CFDictionary
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      pixelFormat,
      attributes,
      &buffer
    )
    guard status == kCVReturnSuccess, let buffer else {
      throw PosterFrameError.invalidPixelBuffer
    }
    return buffer
  }
}
