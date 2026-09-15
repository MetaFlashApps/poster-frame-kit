import CoreMedia

struct DemoVideoPosition: Equatable {
    let timestampSeconds: Double
    let fraction: Double

    init?(time: CMTime, duration: CMTime) {
        let timestampSeconds = time.seconds
        let durationSeconds = duration.seconds
        guard time.isValid,
              time.isNumeric,
              timestampSeconds.isFinite,
              duration.isValid,
              duration.isNumeric,
              durationSeconds.isFinite,
              durationSeconds > 0
        else {
            return nil
        }

        self.timestampSeconds = timestampSeconds
        fraction = min(max(timestampSeconds / durationSeconds, 0), 1)
    }
}
