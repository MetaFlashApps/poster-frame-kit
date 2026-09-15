import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ExampleImportedVideo: Transferable {
  let url: URL
  let displayName: String

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .movie) { received in
      try copy(from: received.file)
    }
  }

  static func copy(from sourceURL: URL) throws -> ExampleImportedVideo {
    let pathExtension = sourceURL.pathExtension
    let temporaryName = pathExtension.isEmpty
      ? UUID().uuidString
      : "\(UUID().uuidString).\(pathExtension)"
    let temporaryURL = URL.temporaryDirectory.appending(path: temporaryName)

    try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
    return ExampleImportedVideo(
      url: temporaryURL,
      displayName: sourceURL.lastPathComponent
    )
  }
}
