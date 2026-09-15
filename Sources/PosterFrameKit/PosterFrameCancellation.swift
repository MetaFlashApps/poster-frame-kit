import Foundation

enum PosterFrameCancellation {
  static func check() throws {
    if Task.isCancelled {
      throw PosterFrameError.cancelled
    }
  }

  static func map<Value>(
    _ operation: () async throws -> Value
  ) async throws -> Value {
    do {
      return try await operation()
    } catch is CancellationError {
      throw PosterFrameError.cancelled
    } catch PosterFrameError.cancelled {
      throw PosterFrameError.cancelled
    } catch {
      if Task.isCancelled {
        throw PosterFrameError.cancelled
      }
      throw error
    }
  }

  static func rethrowIfNeeded(_ error: any Error) throws {
    if error is CancellationError
      || (error as? PosterFrameError) == .cancelled
      || Task.isCancelled
    {
      throw PosterFrameError.cancelled
    }
  }
}
