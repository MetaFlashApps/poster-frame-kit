import CoreGraphics
import CoreImage
import CoreText
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SubtitleFrameRenderer {
  private let imageContext = CIContext(options: [.cacheIntermediates: false])

  func render(
    cue: SubtitleCue,
    style: SubtitleRenderStyle,
    on source: CVPixelBuffer
  ) throws -> CVPixelBuffer {
    guard style != .clean else {
      return source
    }
    let width = CVPixelBufferGetWidth(source)
    let height = CVPixelBufferGetHeight(source)
    var destination: CVPixelBuffer?
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
      &destination
    )
    guard status == kCVReturnSuccess, let destination else {
      throw SubtitleBenchmarkError.imageCreationFailed
    }

    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    imageContext.render(
      CIImage(cvPixelBuffer: source),
      to: destination,
      bounds: bounds,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    try draw(cue: cue, style: style, in: destination)
    return destination
  }

  func writeJPEG(_ pixelBuffer: CVPixelBuffer, to url: URL) throws {
    let image = CIImage(cvPixelBuffer: pixelBuffer)
    let bounds = CGRect(
      x: 0,
      y: 0,
      width: CVPixelBufferGetWidth(pixelBuffer),
      height: CVPixelBufferGetHeight(pixelBuffer)
    )
    guard let cgImage = imageContext.createCGImage(image, from: bounds),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      throw SubtitleBenchmarkError.imageCreationFailed
    }
    CGImageDestinationAddImage(
      destination,
      cgImage,
      [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
      throw SubtitleBenchmarkError.imageCreationFailed
    }
  }

  private func draw(
    cue: SubtitleCue,
    style: SubtitleRenderStyle,
    in pixelBuffer: CVPixelBuffer
  ) throws {
    guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess,
      let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    else {
      throw SubtitleBenchmarkError.imageCreationFailed
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
      | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard let context = CGContext(
      data: baseAddress,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo
    ) else {
      throw SubtitleBenchmarkError.imageCreationFailed
    }

    let fontSize = max(CGFloat(height) * 0.052, 22)
    let font = CTFontCreateWithName(
      "Helvetica Neue Medium" as CFString,
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
        style == .outline ? -6 : 0,
    ]
    let maximumWidth = CGFloat(width) * 0.84
    let lines = wrappedLines(
      cue.lines.map(stripMarkup),
      attributes: attributes,
      maximumWidth: maximumWidth
    )
    let lineSpacing = fontSize * 1.24
    let bottomBaseline = max(CGFloat(height) * 0.065, 18)

    if style == .boxed {
      let widths = lines.map {
        lineWidth($0, attributes: attributes)
      }
      let widest = widths.max() ?? 0
      let padding = fontSize * 0.34
      let box = CGRect(
        x: (CGFloat(width) - widest) / 2 - padding,
        y: bottomBaseline - fontSize * 0.28 - padding,
        width: widest + padding * 2,
        height: lineSpacing * CGFloat(lines.count) + padding * 1.35
      )
      context.setFillColor(CGColor(gray: 0, alpha: 0.72))
      context.fill(box)
    }

    for (index, text) in lines.reversed().enumerated() {
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes)
      )
      let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
      context.textPosition = CGPoint(
        x: (CGFloat(width) - textWidth) / 2,
        y: bottomBaseline + CGFloat(index) * lineSpacing
      )
      CTLineDraw(line, context)
    }
  }

  private func wrappedLines(
    _ sourceLines: [String],
    attributes: [NSAttributedString.Key: Any],
    maximumWidth: CGFloat
  ) -> [String] {
    sourceLines.flatMap { sourceLine in
      let words = sourceLine.split(whereSeparator: \.isWhitespace).map(String.init)
      guard !words.isEmpty else {
        return [""]
      }
      var result: [String] = []
      var current = words[0]
      for word in words.dropFirst() {
        let candidate = "\(current) \(word)"
        if lineWidth(candidate, attributes: attributes) <= maximumWidth {
          current = candidate
        } else {
          result.append(current)
          current = word
        }
      }
      result.append(current)
      return result
    }
  }

  private func lineWidth(
    _ string: String,
    attributes: [NSAttributedString.Key: Any]
  ) -> CGFloat {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: string, attributes: attributes)
    )
    return CTLineGetTypographicBounds(line, nil, nil, nil)
  }

  private func stripMarkup(_ string: String) -> String {
    string.replacingOccurrences(
      of: "<[^>]+>",
      with: "",
      options: .regularExpression
    )
  }
}
