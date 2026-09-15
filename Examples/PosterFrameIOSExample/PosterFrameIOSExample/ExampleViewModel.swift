import Combine
import CoreGraphics
import Foundation
import PhotosUI
import PosterFrameKit
import SwiftUI

@MainActor
final class ExampleViewModel: ObservableObject {
  @Published private(set) var state: ExampleAnalysisState = .idle

  private var analysisTask: Task<Void, Never>?

  func handleFileImport(_ result: Result<URL, any Error>) {
    switch result {
    case .success(let url):
      analyze(
        url,
        fileName: url.lastPathComponent,
        requiresSecurityScopedAccess: true,
        removesVideoAfterAnalysis: false
      )
    case .failure(let error):
      guard (error as? CocoaError)?.code != .userCancelled else {
        return
      }
      state = .failure(fileName: nil, message: error.localizedDescription)
    }
  }

  func handlePhotoImport(_ item: PhotosPickerItem) async {
    analysisTask?.cancel()
    state = .loading(fileName: "Importing from Photos")

    do {
      guard let video = try await item.loadTransferable(
        type: ExampleImportedVideo.self
      ) else {
        state = .failure(
          fileName: nil,
          message: "The selected video could not be imported from Photos."
        )
        return
      }
      if Task.isCancelled {
        try? FileManager.default.removeItem(at: video.url)
        return
      }
      analyze(
        video.url,
        fileName: video.displayName,
        requiresSecurityScopedAccess: false,
        removesVideoAfterAnalysis: true
      )
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else {
        return
      }
      state = .failure(fileName: nil, message: error.localizedDescription)
    }
  }

  private func analyze(
    _ url: URL,
    fileName: String,
    requiresSecurityScopedAccess: Bool,
    removesVideoAfterAnalysis: Bool
  ) {
    analysisTask?.cancel()

    let hasSecurityScopedAccess = requiresSecurityScopedAccess
      && url.startAccessingSecurityScopedResource()
    state = .loading(fileName: fileName)

    analysisTask = Task { [weak self] in
      defer {
        if hasSecurityScopedAccess {
          url.stopAccessingSecurityScopedResource()
        }
        if removesVideoAfterAnalysis {
          try? FileManager.default.removeItem(at: url)
        }
      }

      do {
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await PosterFrameKit.bestFrame(
          in: url,
          options: PosterFrameOptions(
            maximumFramesExamined: 24,
            outputSize: CGSize(width: 1_280, height: 720)
          )
        )
        try Task.checkCancellation()

        self?.state = .success(
          fileName: fileName,
          selection: ExampleSelection(
            result: result,
            elapsed: start.duration(to: clock.now)
          )
        )
      } catch is CancellationError {
        return
      } catch PosterFrameError.cancelled {
        return
      } catch {
        guard !Task.isCancelled else {
          return
        }
        self?.state = .failure(
          fileName: fileName,
          message: error.localizedDescription
        )
      }
    }
  }
}
