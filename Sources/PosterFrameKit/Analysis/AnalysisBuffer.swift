import CoreVideo
import Foundation

struct AnalysisBuffer {
  private(set) var luma: [UInt8] = []
  private(set) var width = 0
  private(set) var height = 0
  private(set) var colorfulness = 0.0

  private let maximumDimension: Int

  init(maximumDimension: Int = 160) {
    self.maximumDimension = maximumDimension
  }

  mutating func load(from pixelBuffer: CVPixelBuffer) throws {
    let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
    let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
    guard sourceWidth > 0, sourceHeight > 0 else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    guard lockStatus == kCVReturnSuccess else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }

    updateDimensions(sourceWidth: sourceWidth, sourceHeight: sourceHeight)

    switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
    case kCVPixelFormatType_32BGRA:
      try loadPackedPixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        layout: .bgra
      )
    case kCVPixelFormatType_32ARGB:
      try loadPackedPixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        layout: .argb
      )
    case kCVPixelFormatType_32RGBA:
      try loadPackedPixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        layout: .rgba
      )
    case kCVPixelFormatType_OneComponent8:
      try loadMonochromePixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight
      )
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
      try loadBiPlanarPixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        isVideoRange: false
      )
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
      try loadBiPlanarPixels(
        from: pixelBuffer,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        isVideoRange: true
      )
    case let format:
      throw PosterFrameError.unsupportedPixelFormat(format)
    }
  }

  private mutating func updateDimensions(sourceWidth: Int, sourceHeight: Int) {
    let scale = min(
      1,
      Double(maximumDimension) / Double(max(sourceWidth, sourceHeight))
    )
    width = max(1, Int((Double(sourceWidth) * scale).rounded()))
    height = max(1, Int((Double(sourceHeight) * scale).rounded()))

    let requiredCount = width * height
    if luma.count < requiredCount {
      luma = Array(repeating: 0, count: requiredCount)
    }
  }

  private mutating func loadPackedPixels(
    from pixelBuffer: CVPixelBuffer,
    sourceWidth: Int,
    sourceHeight: Int,
    layout: PackedPixelLayout
  ) throws {
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    var colorfulnessTotal = 0.0

    // The unsafe access is confined to the locked CVPixelBuffer allocation.
    // Coordinates and byte offsets are bounded by Core Video's dimensions
    // and row stride before each four-byte pixel is read.
    for targetY in 0..<height {
      let sourceY = min(sourceHeight - 1, targetY * sourceHeight / height)
      let row = bytes.advanced(by: sourceY * bytesPerRow)

      for targetX in 0..<width {
        let sourceX = min(sourceWidth - 1, targetX * sourceWidth / width)
        let pixel = row.advanced(by: sourceX * 4)
        let channels = layout.channels(from: pixel)
        let index = targetY * width + targetX

        luma[index] = Self.luma(
          red: channels.red,
          green: channels.green,
          blue: channels.blue
        )

        let maximum = max(channels.red, max(channels.green, channels.blue))
        let minimum = min(channels.red, min(channels.green, channels.blue))
        colorfulnessTotal += Double(maximum - minimum) / 255
      }
    }

    colorfulness = colorfulnessTotal / Double(width * height)
  }

  private mutating func loadMonochromePixels(
    from pixelBuffer: CVPixelBuffer,
    sourceWidth: Int,
    sourceHeight: Int
  ) throws {
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)

    // The buffer remains locked and every sampled coordinate is clamped to
    // the dimensions supplied by Core Video.
    for targetY in 0..<height {
      let sourceY = min(sourceHeight - 1, targetY * sourceHeight / height)
      let row = bytes.advanced(by: sourceY * bytesPerRow)

      for targetX in 0..<width {
        let sourceX = min(sourceWidth - 1, targetX * sourceWidth / width)
        luma[targetY * width + targetX] = row[sourceX]
      }
    }

    colorfulness = 0
  }

  private mutating func loadBiPlanarPixels(
    from pixelBuffer: CVPixelBuffer,
    sourceWidth: Int,
    sourceHeight: Int,
    isVideoRange: Bool
  ) throws {
    guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2,
      let lumaAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
      let chromaAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
    let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
    let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
    guard chromaWidth > 0, chromaHeight > 0 else {
      throw PosterFrameError.invalidPixelBuffer
    }

    let lumaBytes = lumaAddress.assumingMemoryBound(to: UInt8.self)
    let chromaBytes = chromaAddress.assumingMemoryBound(to: UInt8.self)
    let maximumChromaMagnitude =
      isVideoRange
      ? hypot(112.0 as Double, 112.0 as Double)
      : hypot(128.0 as Double, 128.0 as Double)
    var colorfulnessTotal = 0.0

    // Both planes remain locked. Luma and interleaved CbCr offsets use the
    // dimensions and row strides reported for their respective planes.
    for targetY in 0..<height {
      let sourceY = min(sourceHeight - 1, targetY * sourceHeight / height)
      let lumaRow = lumaBytes.advanced(by: sourceY * lumaBytesPerRow)
      let chromaY = min(chromaHeight - 1, sourceY / 2)
      let chromaRow = chromaBytes.advanced(by: chromaY * chromaBytesPerRow)

      for targetX in 0..<width {
        let sourceX = min(sourceWidth - 1, targetX * sourceWidth / width)
        let rawLuma = lumaRow[sourceX]
        luma[targetY * width + targetX] =
          isVideoRange
          ? Self.expandVideoRangeLuma(rawLuma)
          : rawLuma

        let chromaX = min(chromaWidth - 1, sourceX / 2)
        let chromaOffset = chromaX * 2
        let cb = Double(chromaRow[chromaOffset]) - 128
        let cr = Double(chromaRow[chromaOffset + 1]) - 128
        colorfulnessTotal += min(hypot(cb, cr) / maximumChromaMagnitude, 1)
      }
    }

    colorfulness = colorfulnessTotal / Double(width * height)
  }

  private static func luma(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
    let value = 54 * Int(red) + 183 * Int(green) + 19 * Int(blue) + 128
    return UInt8(value >> 8)
  }

  private static func expandVideoRangeLuma(_ value: UInt8) -> UInt8 {
    let clamped = min(max(Int(value), 16), 235)
    return UInt8((clamped - 16) * 255 / 219)
  }
}

enum PackedPixelLayout {
  case argb
  case bgra
  case rgba

  func channels(from pixel: UnsafePointer<UInt8>) -> (red: UInt8, green: UInt8, blue: UInt8) {
    switch self {
    case .argb:
      (pixel[1], pixel[2], pixel[3])
    case .bgra:
      (pixel[2], pixel[1], pixel[0])
    case .rgba:
      (pixel[0], pixel[1], pixel[2])
    }
  }
}
