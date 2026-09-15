# PosterFrameKit – Agent Instructions

These rules apply to the entire repository.

## Safety

- Do not run delete, restore, or reset commands that risk data loss unless the
  user explicitly requests them in the same message.
- Never commit or push autonomously. A commit is allowed only when the user
  explicitly requests it in the current message.
- Existing changes belong to the user and must not be discarded or
  overwritten.
- Keep changes minimal and limited to the current task.

## Product Boundaries

- The initial public release is feature-frozen. Until the first public tag, do
  not add public APIs, options, profiles, metrics, models, or refinements, and
  do not change scoring, sampling, or defaults unless the user explicitly
  lifts the freeze. Reproducible release-blocking bug fixes, tests,
  documentation, and release engineering remain in scope.
- PosterFrameKit selects one or more high-quality poster-frame candidates. It
  is not a video summarizer, an editor, or a container decoder.
- The library must not contain Heiter types, Heiter enums, or Heiter-specific
  assumptions.
- The public API uses only Swift and Apple system types.
- Version 1.x remains free of external package dependencies. Apple frameworks
  such as AVFoundation, Accelerate, Core Video, and optionally Vision are
  allowed.
- Do not use `print` in library code. Diagnostics use an optional callback or
  `os.Logger` with a dedicated subsystem.
- Quality metrics are deterministic and must be backed by tests using
  synthetic and freely licensed fixtures.
- Adopt optimizations only after a reproducible benchmark.

## Architecture

- Keep the public API, sampling, decoding, analysis, scoring, and caching
  separate.
- Do not duplicate shared analysis or scoring logic across AVFoundation and
  custom-decoder paths.
- Serialize stateful decoders, preferably with actors.
- Asynchronous APIs support task cancellation and do not block an actor with
  long-running synchronous work.
- Keep unsafe memory access small, documented, and covered by edge-case tests.
- New public symbols require DocC comments and a Sendable review.

## Tests and Benchmarks

- Every new metric receives isolated unit tests.
- Sampling and ranking changes require deterministic tests.
- Test decoder integrations with at least one short generated video.
- Quality claims require a versioned, freely reproducible benchmark set. Do
  not commit copyrighted anime clips.
- Performance figures state the hardware, OS, resolution, codec, candidate
  count, and cache state.

## Documentation and Versioning

- Document functional changes in `CHANGELOG.md` as part of the same change.
- Changes to behavior or public API update `README.md` and the relevant file
  under `docs/`.
- The roadmap describes intent; `docs/version-1.0.0.md` defines binding release
  criteria.
- Before `1.0.0`, the API may intentionally break; make every such change
  visible in the changelog. Semantic Versioning applies from `1.0.0` onward.

## Definition of Done

- The relevant code is implemented consistently across all affected paths.
- `swift test` succeeds; performance work also runs the relevant benchmarks.
- The public API and concurrency code build under Swift 6.2 without new
  warnings.
- README, changelog, and affected concept or roadmap documents remain in sync.
- No unintended files were deleted, reset, committed, or published.
- Explicitly state open risks and untested platforms.
