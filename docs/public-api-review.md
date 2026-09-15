# Public API Review

This document records the pre-public API review completed on 2026-08-27. It
defines the surface considered suitable for an initial `0.x` release; it is not
the final `1.0.0` freeze. External integration feedback may still justify
source-breaking changes while the package is pre-1.0.

This reviewed surface is feature-frozen for the initial `0.1.0` publication.
Until that tag, only reproducible release-blocking fixes may alter behavior;
new API and product work resumes after the release.

## Accepted Shape

- `PosterFrameKit` remains a namespace with four operations: URL selection,
  custom-source selection, direct pixel-buffer evaluation, and a separate
  AVFoundation embedded-artwork lookup.
- `PosterFrameOptions` is the single selection configuration value. Its nested
  face, subtitle, and aesthetics values keep expensive refinements explicit and
  disabled by default.
- `PosterFrameOptions.normalized()` remains public so custom pipelines can
  apply the same deterministic validation as the built-in entry points.
- `PosterFrameSource` remains the decoder boundary and exposes only Apple
  system types. Stateful implementations are expected to use actor isolation.
- `PosterFrameResult` keeps the base score and every optional adjustment
  separate so final ranking remains inspectable.
- Embedded artwork returns `CGImage?` rather than becoming an option or a
  synthetic `PosterFrameResult`; callers explicitly choose whether deliberate
  container artwork precedes generated frame selection.
- `PosterFrameError.cancelled` is the one documented cancellation result from
  public asynchronous operations, regardless of whether a source or Apple
  framework reports `CancellationError`.

## Release-Surface Decisions

- Package versions are represented by Git tags and release metadata, not a
  hard-coded public runtime string that can drift from the resolved package.
- `CGImage` and `CVPixelBuffer` wrappers retain documented `@unchecked
  Sendable` conformances. Callers must not mutate a returned pixel buffer while
  PosterFrameKit is analyzing it.
- Vision aesthetics remains callable through an availability-neutral option.
  Unsupported operating systems preserve the deterministic fallback rather
  than making the whole selection API availability-gated.
- The uncalibrated `liveAction` and `screencast` profile experiments were
  removed before the first public release. `general` remains suitable for
  varied and photographic material, while `custom` preserves an explicit
  escape hatch without promising unsupported preset weights.

## Verification

- Swift's emitted public symbol graph contains DocC comments for every exported
  declaration.
- A consumer-style test imports `PosterFrameKit` without `@testable` and covers
  option composition, normalization, direct evaluation, custom-source
  selection, result construction, AVFoundation source construction, and the
  embedded-artwork lookup.
- DocC builds successfully for macOS without unresolved-link failures.

## Release API Baseline

The `0.1.0` tag is the reproducible source baseline for later API comparisons.
After the tag exists, check an update with the same Swift toolchain:

```bash
swift package diagnose-api-breaking-changes 0.1.0 --products PosterFrameKit
```

Generate a public symbol graph with `swift package dump-symbol-graph` when
needed. Generated graphs remain under ignored `.build/`; platform-dependent
compiler output is not checked into the source tree as a second API authority.

## Required Before the 1.0 Freeze

- Exercise the first tagged beta from at least one external consumer.
- Revisit every experimental option using the versioned quality fixtures.
- Compare the final symbol graph with the first public tag and document all
  intentional source-breaking changes.
- Complete the platform availability and CI matrix in
  [PosterFrameKit 1.0.0](version-1.0.0.md).
