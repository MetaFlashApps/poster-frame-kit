@preconcurrency import AVFoundation
import Foundation
@testable import PosterFrameKit

enum GeneratedVideoFixture {
    static func make(artworkData: Data? = nil) async throws -> URL {
        let fileType: AVFileType = artworkData == nil ? .mp4 : .mov
        let fileExtension = artworkData == nil ? "mp4" : "mov"
        let url = FileManager.default.temporaryDirectory
            .appending(path: "PosterFrameKit-\(UUID().uuidString).\(fileExtension)")
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        if let artworkData {
            let artwork = AVMutableMetadataItem()
            artwork.identifier = .quickTimeMetadataArtwork
            artwork.dataType = kCMMetadataBaseDataType_PNG as String
            artwork.value = artworkData as NSData
            writer.metadata = [artwork]
        }
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
            throw PosterFrameError.unsupportedVideo
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? PosterFrameError.unsupportedVideo
        }
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<12 {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                await Task.yield()
            }

            let buffer = try frame(frameIndex, width: width, height: height)
            let presentationTime = CMTime(value: Int64(frameIndex), timescale: 6)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? PosterFrameError.unsupportedVideo
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? PosterFrameError.unsupportedVideo
        }
        return url
    }

    private static func frame(
        _ index: Int,
        width: Int,
        height: Int
    ) throws -> CVPixelBuffer {
        try TestPixelBufferFactory.bgra(width: width, height: height) { x, y in
            switch index {
            case 0..<4:
                (blue: 0, green: 0, red: 0)
            case 4..<8:
                (blue: 128, green: 128, red: 128)
            default:
                ((x / 8 + y / 8).isMultiple(of: 2))
                    ? (blue: 24, green: 24, red: 24)
                    : (blue: 235, green: 235, red: 235)
            }
        }
    }
}
