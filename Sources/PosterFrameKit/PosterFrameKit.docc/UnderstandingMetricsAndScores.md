# Understanding Metrics and Scores

Inspect the measurements that explain why PosterFrameKit selected a frame.

## Metrics

PosterFrameKit calculates metrics from a deterministic, downsampled analysis
buffer:

- `meanLuma` measures average brightness from `0` (black) to `1` (white).
- `lumaDeviation` measures contrast as population standard deviation.
- `entropy` measures normalized Shannon entropy of the luma histogram.
- `sharpness` uses normalized Tenengrad edge strength. Tenengrad was chosen for
  the first release because it responds to strong, well-defined edges without
  treating absolute brightness as detail.
- `colorfulness` estimates average chroma magnitude and remains a soft signal.
- `visualNoise` estimates dense, incoherent high-frequency energy. It remains
  zero for ordinary edges and moves smoothly toward one for static-like
  patterns.

The analyzer supports 8-bit BGRA, ARGB, RGBA, monochrome, and bi-planar 4:2:0
full- and video-range pixel buffers. Other formats throw
``PosterFrameError/unsupportedPixelFormat(_:)`` rather than entering an unsafe
conversion path.

## Scores

Scores combine metrics with profile weights, reduce uniformly dark or bright
frames, softly penalize frames without detail, and apply a visual-noise penalty
capped at 25%. Scores stay in `0...1`; they are useful for comparing candidates
produced by the same algorithm version, not as universal aesthetic ratings.

The public `entropy` metric remains normalized Shannon entropy of the complete
luma histogram. During scoring, PosterFrameKit limits only its contribution
when coherent Tenengrad structure is nearly absent. This prevents a smooth
grayscale ramp or dense visual noise from receiving a full information-density
reward merely because it occupies many histogram bins. Ordinary frames with
clear edges retain their raw entropy contribution.

Evaluate a frame without sampling a video:

```swift
let evaluation = try PosterFrameKit.evaluate(
    pixelBuffer: decodedFrame,
    profile: .general
)

let score = evaluation.score
let metrics = evaluation.metrics
```

Custom weights must be finite and nonnegative. Option normalization scales the
four metric weights to a combined total of `1`.

Optional subtitle avoidance, face preference, and aesthetic preference do not
change these metrics or the base score. They report their bounded adjustments
separately as
``PosterFrameResult/subtitlePenalty`` and
``PosterFrameResult/faceCompositionBonus``, and
``PosterFrameResult/aestheticAdjustment``. The optional raw Vision value is
available as ``PosterFrameResult/aestheticScore``; it is an OS-model output,
not a universal quality rating. The final value used for candidate comparison
is ``PosterFrameResult/adjustedScore``.
