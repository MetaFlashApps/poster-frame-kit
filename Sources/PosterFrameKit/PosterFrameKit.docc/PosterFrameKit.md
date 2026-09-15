# ``PosterFrameKit``

Select one deterministic, explainable poster frame from a video.

## Overview

PosterFrameKit samples a bounded number of decoded frames, calculates compact
image-quality metrics, and returns the strongest candidate with its actual
timestamp, base score, optional refinement, and metrics. The package uses Apple
system frameworks and has no external package dependencies.

Use ``PosterFrameKit/bestFrame(in:options:)`` for videos supported by
AVFoundation, or implement ``PosterFrameSource`` to connect another decoder.
Every selection applies ``PosterFrameOptions/normalized()`` before accessing a
frame source. Use ``PosterFrameKit/embeddedArtwork(in:)`` first when deliberate
cover art stored in AVFoundation metadata should take precedence over a
generated frame.

```swift
import PosterFrameKit

var options = PosterFrameOptions(profile: .animation)
options.maximumFramesExamined = 40
options.excludedRanges = [0.46...0.54]
options.subtitleAvoidance = PosterFrameSubtitleOptions(
    candidateCount: 8,
    maximumPenalty: 0.08
)
options.facePreference = PosterFrameFaceOptions(
    candidateCount: 8,
    maximumBonus: 0.04
)
options.aestheticPreference = PosterFrameAestheticOptions(
    candidateCount: 24,
    maximumAdjustment: 1
)
options.outputSize = CGSize(width: 1_280, height: 720)

let result = try await PosterFrameKit.bestFrame(
    in: videoURL,
    options: options
)
```

Embedded artwork is deliberately separate from selection because it has no
decoded timestamp, quality score, or frame metrics:

```swift
if let artwork = try await PosterFrameKit.embeddedArtwork(in: videoURL) {
    display(artwork)
} else {
    let result = try await PosterFrameKit.bestFrame(
        in: videoURL,
        options: options
    )
    display(result.image)
}
```

`candidateCount` limits expensive optional analysis to the strongest base
candidates. `maximumPenalty` bounds the subtitle score reduction, while
`maximumBonus` bounds the face-composition increase, while
`maximumAdjustment` bounds the signed change used to align the deterministic
base score with Vision's normalized aesthetics result. Pass `nil` for an option
to skip that Vision analysis entirely.

## Topics

### Essentials

- <doc:SelectingPosterFrames>
- ``PosterFrameKit/embeddedArtwork(in:)``
- ``PosterFrameKit/bestFrame(in:options:)``
- ``PosterFrameOptions``
- ``PosterFrameSubtitleOptions``
- ``PosterFrameFaceOptions``
- ``PosterFrameAestheticOptions``
- ``PosterFrameResult``
- ``PosterFrameError``

### Frame Analysis

- <doc:UnderstandingMetricsAndScores>
- ``PosterFrameKit/evaluate(pixelBuffer:profile:)``
- ``FrameMetrics``
- ``PosterFrameProfile``
- ``PosterFrameWeights``

### Frame Sources

- <doc:ProvidingCustomFrames>
- ``AVFoundationFrameSource``
- ``PosterFrameSource``
- ``PosterFrameSample``
- ``PosterFrameKit/bestFrame(from:options:)``
