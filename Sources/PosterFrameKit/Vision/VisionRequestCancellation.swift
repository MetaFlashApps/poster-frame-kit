@preconcurrency import Vision

final class VisionRequestCancellation: @unchecked Sendable {
    private let request: VNRequest

    init(request: VNRequest) {
        self.request = request
    }

    func cancel() {
        request.cancel()
    }
}
