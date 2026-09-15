# Changelog

All notable changes to PosterFrameKit are documented here.
Before 1.0.0, minor releases may intentionally introduce API changes.

## 0.1.0 - 2026-09-15

Initial public release.

### Added

- Native Swift 6.2 package for macOS 13+, iOS 16+, tvOS 16+, and visionOS 1+,
  without external package dependencies or runtime downloads.
- URL-based AVFoundation selection, custom `PosterFrameSource` selection,
  direct pixel-buffer evaluation, and explicit embedded-artwork lookup.
- Validated and normalized search ranges, exclusions, candidate budgets,
  output bounds, and general, animation, or custom scoring profiles.
- Deterministic sampling, actual-time deduplication, stable tie resolution,
  task cancellation, and shared analysis across decoder paths.
- Explainable brightness, contrast, entropy, sharpness, colorfulness, and
  visual-noise metrics, with structure-qualified entropy scoring and bounded
  noise penalties.
- Benchmark-validated, bounded parallel AVFoundation decoding on macOS;
  iOS, tvOS, visionOS, and custom sources retain serialized decoding.
- Opt-in lower-third subtitle avoidance and face-composition preference.
- Opt-in Vision-first image aesthetics on macOS 15+, iOS 18+, tvOS 18+, and
  visionOS 2+, with deterministic fallback on unsupported systems.
- Separate result evidence for base score, subtitle penalty, face bonus,
  aesthetic adjustment, and final ranking score.
- Native macOS comparison Demo with candidate browsing, PNG export, per-frame
  metrics, and explicit workflow timings.
- iOS example with video-filtered Photos import, Files fallback, and public
  result inspection.
- Synthetic unit tests, public consumer tests, generated-video integrations,
  and reproducible freely licensed quality and calibration fixtures.
- Dependency-free performance, quality, and subtitle benchmark harnesses,
  documented reports, and an attributed results gallery.
- DocC API documentation, static-site generation, and a release-triggered
  GitHub Pages deployment workflow.
- GitHub Actions package/Demo tests, release builds, iOS Simulator consumer
  tests, Apple platform compile checks, DocC, and release-hygiene validation.

### Known Limits

- Optional Vision preferences are best effort; stylized faces and ambiguous
  lower-third text may not be recognized as intended.
- tvOS and visionOS have CI compile coverage, not physical-device validation.
- Dedicated container decoding, persistent caching, and content moderation
  remain outside the package.
