import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum DemoThumbnailExporter {
    @MainActor
    static func requestSave(
        image: CGImage,
        title: String
    ) async throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename(for: title)

        guard await panel.begin() == .OK, let destinationURL = panel.url else {
            return
        }

        try writePNG(image, to: destinationURL)
    }

    static func suggestedFilename(for title: String) -> String {
        let components = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let stem = components.joined(separator: "-")
        return stem.isEmpty ? "thumbnail.png" : "\(stem)-thumbnail.png"
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CocoaError(
                .fileWriteUnknown,
                userInfo: [
                    NSLocalizedDescriptionKey: "The PNG destination could not be created.",
                ]
            )
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(
                .fileWriteUnknown,
                userInfo: [
                    NSLocalizedDescriptionKey: "The thumbnail could not be encoded as PNG.",
                ]
            )
        }
    }
}
