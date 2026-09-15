# Providing Custom Frames

Connect a decoder without adding its container or codec dependencies to
PosterFrameKit.

## Implement the Source Contract

A source reports a finite duration and decodes frames asynchronously. Stateful
decoders should use an actor so seeking and decoding remain serialized.

```swift
actor MyFrameSource: PosterFrameSource {
    let duration: CMTime

    init(duration: CMTime) {
        self.duration = duration
    }

    func frame(
        at time: CMTime,
        maximumSize: CGSize?
    ) async throws -> PosterFrameSample {
        let decoded = try await decoder.frame(at: time, maximumSize: maximumSize)
        return PosterFrameSample(
            pixelBuffer: decoded.pixelBuffer,
            requestedTime: time,
            actualTime: decoded.actualTime
        )
    }
}
```

Return display-oriented pixel data and do not mutate a returned buffer while
PosterFrameKit is analyzing it. Honor `maximumSize` as a bounding size when the
decoder supports scaled output.

## Select From the Source

```swift
let result = try await PosterFrameKit.bestFrame(
    from: source,
    options: PosterFrameOptions(profile: .animation)
)
```

PosterFrameKit owns sampling, deduplication, analysis, scoring, and tie-breaking.
The custom source remains responsible only for duration and decoding. This is
the integration point for containers such as MKV; PosterFrameKit itself does not
embed a container decoder.
