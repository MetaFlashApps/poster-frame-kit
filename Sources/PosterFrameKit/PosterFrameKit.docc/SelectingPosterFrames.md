# Selecting Poster Frames

Configure a bounded search and select one candidate from an AVFoundation video.

## Choose a Profile

The `general` profile balances all current metrics. The `animation` profile
places more weight on sharpness and contrast. Use `custom` only when measured
material requires caller-controlled weights.

```swift
let options = PosterFrameOptions(
    searchRange: 0.08...0.90,
    maximumFramesExamined: 40,
    excludedRanges: [0.46...0.54],
    profile: .animation,
    subtitleAvoidance: PosterFrameSubtitleOptions(
        candidateCount: 8,
        maximumPenalty: 0.08
    ),
    facePreference: PosterFrameFaceOptions(
        candidateCount: 8,
        maximumBonus: 0.04
    ),
    aestheticPreference: PosterFrameAestheticOptions(
        candidateCount: 24,
        maximumAdjustment: 1
    ),
    outputSize: CGSize(width: 1_280, height: 720)
)
```

`searchRange` uses normalized video positions: `0` is the beginning and `1` is
the end. `excludedRanges` removes planned timestamps in predictable unwanted
sections, such as an anime midroll eyecatch. The output size is a maximum pixel
bounding box; it does not crop the image or change its aspect ratio.

## Run the Selection

If deliberate embedded cover art should win without frame analysis, perform
that lookup explicitly before selection:

```swift
if let artwork = try await PosterFrameKit.embeddedArtwork(in: videoURL) {
    display(artwork)
    return
}
```

The lookup reads AVFoundation's common artwork metadata. It returns `nil` when
there is no decodable artwork and does not create a synthetic
``PosterFrameResult`` because artwork has no video timestamp or frame metrics.
Custom container adapters remain responsible for their own attachments.

```swift
let result = try await PosterFrameKit.bestFrame(
    in: videoURL,
    options: options
)

display(result.image)
inspect(result.time, result.score, result.metrics)
```

PosterFrameKit requests evenly distributed timestamps across the inclusive
search range and then removes timestamps covered by an exclusion. Therefore an
exclusion can reduce the number actually requested below
`maximumFramesExamined`. If the midpoint of a single-candidate request is
excluded, PosterFrameKit uses the midpoint of the widest remaining interval,
preferring the earlier interval when widths match. Decoders may return a nearby
timestamp; PosterFrameKit deduplicates identical actual timestamps and returns
the actual timestamp of the winner.

Base selection is deterministic for identical source behavior and options.
When two candidates have equal scores, the earlier actual timestamp wins.

## Prefer a Subtitle-Free Candidate

Set ``PosterFrameOptions/subtitleAvoidance`` to a
``PosterFrameSubtitleOptions`` value to re-rank a bounded group of leading
candidates. The default configuration inspects at most eight candidates and
applies at most a `0.08` score reduction.

The local Vision analyzer recognizes text only in the bottom third. It starts
with fast recognition and uses accurate recognition only when the fast result
is empty but a cheap edge-band check is suspicious. PosterFrameKit can stop
once an uninspected base score cannot beat the current adjusted winner. A
recognition error discards the entire optional stage; cancellation remains an
error.

This policy targets common burned-in subtitles rather than text generally.
Signs outside the lower-third region remain eligible, while signs or credits
inside that region may still be penalized. The generated calibration fixture
locks this distinction with dialogue, credit, clean, and central-sign controls.
Inspect
``PosterFrameResult/score``, ``PosterFrameResult/subtitlePenalty``, and
``PosterFrameResult/adjustedScore`` to see the result.

## Prefer Strong Face Composition

Set ``PosterFrameOptions/facePreference`` to a
``PosterFrameFaceOptions`` value to inspect a bounded group of leading
candidates with local Vision face detection. The default configuration checks
at most eight candidates and applies at most a `0.04` score increase.

The composition scorer weights Vision's detector confidence, rewards visible,
usefully sized faces near the central composition, and applies a small capped
group bonus. Observations below `0.70` confidence, tiny detections, and extreme
close-ups receive no bonus. A candidate without a reliable detected face
receives no penalty, so strong landscapes and object shots remain eligible.

PosterFrameKit reuses the already decoded pixel buffers and stops once a later
candidate cannot overtake the current winner even with the maximum bonus. A
detection error discards face bonuses; cancellation remains an error. Inspect
``PosterFrameResult/faceCompositionBonus`` and
``PosterFrameResult/adjustedScore`` to see the result. Face detection is best
effort and may miss strongly stylized animation. The threshold and bounded
runtime were calibrated against the repository's freely licensed core videos;
see the repository's `docs/face-calibration.md` report for limitations.

## Prefer an Aesthetic Candidate

Set ``PosterFrameOptions/aestheticPreference`` to a
``PosterFrameAestheticOptions`` value to apply Apple Vision image-aesthetics
analysis to a bounded group of leading candidates. The default checks at most
24 candidates and aligns PosterFrameKit's base score with Vision's normalized
`0...1` aesthetic score.

PosterFrameKit reuses the already decoded pixel buffers and stops once a later
candidate cannot overtake the current winner even with the maximum positive
adjustment. ``PosterFrameResult/aestheticScore`` exposes the raw Vision score,
``PosterFrameResult/isUtilityFrame`` exposes its utility classification, and
``PosterFrameResult/aestheticAdjustment`` exposes the applied score change.
Vision already incorporates utility classification into its overall score, so
there is no additional hidden penalty.

The analyzer is available on macOS 15+, iOS 18+, tvOS 18+, and visionOS 2+.
Earlier systems keep the deterministic ranking from the preceding stages.
Analysis errors also roll back only this optional stage; cancellation remains
an error. This is the recommended quality configuration where available;
PosterFrameKit's metrics remain the explainable fallback and supply the
candidate pool on every platform.

The 24-candidate default is the conservative quality-first cap. Applications
that prioritize latency can explicitly set `candidateCount` to `8`; the
repository's initial freely licensed calibration measured a lower runtime but
also found one different, visually competitive live-action selection. A
smaller cap therefore narrows the shortlist by caller choice rather than
silently changing the quality policy.

When multiple optional preferences are enabled, face bonuses are applied
first, subtitle penalties follow, and aesthetic adjustments are applied last.

## Handle Cancellation

Cancel the task that is awaiting selection. PosterFrameKit checks cancellation
before and after source calls and between candidates, then throws
``PosterFrameError/cancelled``.

```swift
let task = Task {
    try await PosterFrameKit.bestFrame(in: videoURL, options: options)
}

task.cancel()
```
