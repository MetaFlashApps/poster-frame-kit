# PosterFrameKit 1.0.0

This document defines what `1.0.0` means. It is not a wish list; it is the
release acceptance specification.

## Release Promise

PosterFrameKit 1.0.0 selects an explainable poster frame from a local video file
or a custom frame source on supported Apple platforms. Its base ranking is
deterministic, and optional Apple Vision refinements expose their effects
separately. The package can be integrated through Swift Package Manager
without external package dependencies or runtime downloads.

## Supported Platforms

- macOS 13+
- iOS 16+
- tvOS 16+
- visionOS 1+
- Swift 6.2+

At minimum, macOS and iOS must be covered by CI or documented release checks
before release. tvOS and visionOS must not merely appear in the manifest:
buildability and unavailable framework paths must be verified.

Recorded remote and physical-device checks live in
[`release-validation.md`](release-validation.md). The first physical consumer
check passed on an iPhone 11 Pro running iOS 26.6.1; this is evidence for that
device path, not a claim of complete iOS-version or device coverage.

## Stable Public API

Version 1.0 contains at least:

```swift
PosterFrameKit.bestFrame(in:options:)
PosterFrameKit.embeddedArtwork(in:)
PosterFrameKit.evaluate(pixelBuffer:profile:)
PosterFrameOptions
PosterFrameSubtitleOptions
PosterFrameFaceOptions
PosterFrameAestheticOptions
PosterFrameProfile
PosterFrameWeights
PosterFrameResult
FrameMetrics
PosterFrameSource
PosterFrameSample
PosterFrameError
```

The final signatures may differ from this draft. Before tagging the release,
however, all of the following must hold:

- complete DocC comments
- Swift 6.2 concurrency without new warnings
- cancellation is documented and tested
- the actual frame timestamp is returned
- `CGImage` orientation and `outputSize` semantics are unambiguous
- options are validated and normalized deterministically before accessing a
  frame source
- optional candidate refinements document their disabled defaults, bounded
  work, ranking effects, failure semantics, and cancellation behavior
- normalized exclusion ranges are merged deterministically and tested as part
  of candidate planning
- AVFoundation returns transformed, display-ready images; custom sources also
  provide their pixel buffers in display orientation
- `outputSize` is a maximum pixel bounding box without cropping or forced
  upscaling
- embedded artwork remains an explicit `CGImage?` lookup with documented
  absence, malformed-data, metadata-error, and cancellation semantics
- custom sources can be implemented without application-specific or
  third-party decoder types in the public API

`bestFrames` for multiple candidates is part of 1.0 only if a confirmed
external use case exists by the beta.

## Quality Criteria

The versioned test set contains at least:

- animation with clear lines
- dark and bright fades
- crossfade or motion blur
- dense visual noise or static
- letterboxed or pillarboxed material
- low colorfulness
- live action with film grain
- screencast or title cards
- burned-in subtitles
- photographic and stylized faces, groups, extreme close-ups, and no-face
  scenes for the optional face preference
- aesthetically strong and intentionally plain utility frames across animation
  and live action for the optional OS-versioned aesthetics preference
- very short video
- video with coarse seek or keyframe intervals

Each clip defines acceptable time ranges or an ordered candidate list. The
evaluation is not constrained to one exact frame when multiple frames are
visually equivalent.

Acceptance:

- no black or white fade when an acceptable candidate exists
- dense visual noise does not win solely through elevated entropy and edge
  energy when an acceptable structured candidate exists
- no crash for supported pixel formats and a documented error for unknown
  formats
- deterministic selection policy for identical input, options, and algorithm;
  release notes document any platform-level Vision-model variation found by
  the fixture suite
- `animation` performs no worse than `general` on the animation subset
- compared with a fixed 50% frame, the overall assessment of the curated set
  improves according to documented human evaluation

## Performance Criteria

There is no hardware-independent millisecond guarantee. The release includes
reproducible measurements that state:

- device, chip, RAM, and OS
- codec, resolution, and video duration
- candidate count and profile
- cold and warm cache state
- runtime and peak memory

Provisional product target on a current Apple Silicon Mac:

- approximately 30 seconds of local H.264: typically below 500 ms
- no linear full-frame scan for long videos
- bounded memory proportional to the candidate pipeline, not video duration

These targets may change after the first benchmark. Every adjustment is
justified in the changelog. The ordered experiments and their measurement gates
are tracked in the [Performance Roadmap](performance-roadmap.md); the release
criteria in this document remain binding.

## Reliability

- GitHub CI tests debug behavior, builds release configurations and DocC, and
  compiles the package for every declared Apple platform using Swift 6.2
- Unit tests for every metric and scoring boundary
- Integration tests for AVFoundation frame selection and embedded artwork
- Contract tests for a synthetic `PosterFrameSource`
- Tests for cancellation, an empty source, invalid options, and duplicate
  frames
- Generated H.264 end-to-end tests for the package, benchmark fixture, and Demo
  workflow without checked-in copyrighted media
- A real iOS consumer host imports the local package through its public product
  and provides file-backed Photos and Files video import with visible progress,
  failure, selected image, timestamp, score, elapsed duration, and public
  metric states. It also
  runs synthetic evaluation, generated H.264 URL selection, and optional Vision
  paths with their documented fallback in an iOS Simulator process
- No data races under Thread Sanitizer in the relevant tests
- No library `print` output
- No uncaught precondition or force-unwrap crashes caused by input data

## Documentation and Community

- README with a real one-line example and results gallery
- Installation example using a tagged remote version
- DocC for all public symbols
- Current concept, architecture, and non-goals
- Documented benchmark scripts and fixture sources
- `CHANGELOG.md`, `LICENSE`, and contribution guide
- a third-party notice for every bundled artifact, with release approval for
  any upstream license or training-data ambiguity
- Submission to the Swift Package Index

## Not Part of 1.0

- semantic understanding of the story
- a guarantee of the objectively “best” artistic frame
- video summaries or full-scene clustering
- a dedicated MKV or AVI decoder
- automatic cropping of the returned image
- cloud service, telemetry, or user account
- cloud-hosted or runtime-downloaded models
- persistent thumbnail or media-library cache

## Release Checklist

- [ ] The roadmap's Stable Release milestone is complete
- [ ] Complete test suite passes
- [ ] Platform matrix verified
- [ ] Benchmarks reproduced
- [ ] API review complete
- [ ] At least one external consumer successfully uses the release candidate
- [ ] Final beta tag has no open critical defects
- [ ] README and DocC exactly match the final API
- [ ] `CHANGELOG.md` contains complete 1.0.0 release notes
- [ ] Git tag and GitHub release created
