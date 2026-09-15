# PosterFrameKit – Roadmap

This roadmap contains only planned work for the public package. Completed
changes belong in the [changelog](../CHANGELOG.md), measured and rejected
experiments in [research findings](research-findings-2026-08.md), and the
binding stable-release criteria in [version-1.0.0.md](version-1.0.0.md).
The [release hygiene audit](release-hygiene.md) tracks repository,
branch-publication, security-reporting, and bundled-license checks.
The detailed [Performance Roadmap](performance-roadmap.md) defines the ordered
benchmark questions and acceptance gates for optimization work through 1.0.

Application-specific work is intentionally separate. See
[Heiter Integration](heiter-integration.md) for the first consumer's adapter,
container, caching, and rollout plan.

## Current State (`0.1.0` Release Candidate)

The package already provides deterministic AVFoundation and custom-source
selection, explainable image metrics, bounded macOS decoder parallelism,
optional midroll exclusion, best-effort subtitle
refinement, optional face-composition and Apple Vision aesthetics preferences,
an explicit AVFoundation embedded-artwork lookup, DocC, a native comparison
demo, and a reproducible performance harness.

The initial public API and feature set are frozen. Remaining `0.1.0` work is
limited to validation, documentation corrections, release-blocking bug fixes,
and publication tasks tracked in the
[`0.1.0` release checklist](version-0.1.0.md). Unchecked calibration and product
experiments below are post-release work, not blockers for the first public tag.

Five guardrails apply:

- no new public API, options, profiles, metrics, models, ranking policies, or
  default changes before `0.1.0` unless the freeze is explicitly lifted;
- public behavior changes require reproducible quality evidence;
- performance changes require before-and-after runtime and memory reports;
- experimental optimizations remain internal and are removed when they do not
  produce a repeatable overall win; and
- the demo distinguishes shared-candidate quality comparisons from true
  end-to-end workflow timings.

## Completed – Reproducible Quality Baseline

- [x] Complete an initial pre-public API audit, remove the hard-coded runtime
      development version, verify exported DocC coverage, and add a
      consumer-style test that uses no `@testable` access
- [x] Add an iOS 16 consumer host whose simulator tests exercise public
      pixel-buffer evaluation, generated H.264 URL selection, and optional
      Vision paths with safe fallback, and run it in CI on a dynamically
      selected current iPhone Simulator
- [x] Establish a versioned fixture manifest and fetch pipeline as the source
      of truth for freely licensed source URLs, byte counts, checksums,
      licenses, normalization recipes, semantic tags, profiles, and initially
      reviewed acceptable time ranges
- [x] Add the initial checksum-locked 2D/3D animation and live-action core set;
      catalog the impractically large Meridian and Sol Levante masters as
      deferred rather than downloading them implicitly
- [x] Add a three-way real-material quality harness for PosterFrameKit,
      pure Vision, and a transparent 50/50 hybrid; record the first reviewed
      24-candidate ARM64 baseline and use Vision-first aesthetics as the
      recommended supported-OS configuration with deterministic fallback
- [x] Register the archived generated patterns and subtitle variant in the same
      quality catalog, then add very short videos and coarse seek points
- [x] Produce a small results gallery comparing a fixed 50% frame with
      PosterFrameKit on redistributable material
- [x] Repeat the `8`, `16`, `24`, and `40` candidate-budget comparison on the
      shared quality set; retain `24` as the documented quality-first Demo
      budget and `8` as speed-first, without changing the package default until
      its deterministic configuration is compared separately
- [x] Structure-qualify the entropy scoring contribution so an evenly
      distributed grayscale gradient cannot beat clearer structured content
      merely through histogram entropy, while keeping the public raw metric and
      reviewed real-video winners unchanged

Exit criterion: every scoring or sampling change can be evaluated against one
versioned, freely reproducible quality set without duplicating fixture metadata.

## After `0.1.0` – Calibration and Hardening

- [x] Expand the [generated subtitle fixture](subtitle-calibration.md) with
      lower-third dialogue and credit text, a clean control, and a central
      scene sign; lock the intended text boundary with a decoded-H.264 Vision
      integration test
- [x] Add a first checksum-locked real-material subtitle calibration using
      matched Tears of Steel frames, official English/German cues, outline and
      boxed styles, clean controls, an actual lower-third credit, and an
      explicit ambiguity set; use it to recover measured small-outline misses
- [ ] Expand subtitle calibration to native burned-in subtitles across freely
      licensed 2D/3D animation, more live action, writing systems, typography,
      clean dialogue scenes, and ambiguous lower-third signs before considering
      subtitle avoidance as a default
- [x] Calibrate face preference over every candidate in the five freely
      licensed core videos; record raw and scored detections, bounds,
      confidence, repeatability, contact sheets, ranking effects, and paired
      process-cold/process-warm runtime
- [ ] Expand [face calibration](face-calibration.md) beyond the core videos
      with dedicated stylized-face, group, extreme-close-up, and human-no-face
      fixtures before considering any default behavior change
- [x] Compare `8`, `12`, `16`, and `24` Vision-aesthetics shortlist caps across
      the five freely licensed core videos and generated technical controls;
      retain 24 for quality-first use and document eight as a measured
      latency-first alternative
- [ ] Expand [aesthetics calibration](aesthetic-calibration.md) beyond the core
      set with intentionally plain utility frames and composition outliers
      across animation and live action, reviewed by multiple people
- [x] Compare against FFmpeg's `thumbnail` filter on the public quality set;
      record full-scan quality evidence separately from architecture-matched
      performance claims
- [x] Turn the iOS consumer host into a focused manual example with
      a video-filtered Photos picker, Files fallback, file-backed media
      transfer, progress and error states, the selected poster frame,
      timestamp, score, and compact public metrics. Keep candidate browsing,
      comparisons, and advanced tuning in the macOS Demo. Before publication,
      remove the repository's development-team binding, disable signing for
      simulator builds, and exclude all nested Xcode per-user state.
- [x] Move demo orchestration out of `DemoViewModel`, release comparison
      candidate buffers promptly, and keep all displayed timing boundaries
      explicit
- [x] Record an initial documented performance and memory baseline for the
      accepted 8/16/24/40 candidate matrix and optional Vision configuration;
      reproduce the final profile after quality behavior is frozen

Exit criterion: the supported profiles and optional refinements have documented
quality limits, and the demo can inspect them without owning an oversized
coordination object.

## Initial Public Release (`0.1.0`)

- [ ] Publish the repository publicly under the MetaFlash organization
- [x] Add contribution and security guides plus fixture provenance and license
      documentation
- [ ] Publish only the reviewed clean-history `main`; keep development
      archives private
- [ ] Require both successful checks on the protected default branch. The first
      green remote run is recorded in
      [release validation](release-validation.md), and the least-privilege
      Swift 6.2 workflow covers
      package and Demo tests, release builds, DocC, hygiene, and generic builds
      for every supported Apple platform
- [ ] Publish DocC
- [x] Document API comparison against the first public tag in the
      [public API review](public-api-review.md#release-api-baseline)
- [ ] Submit the package to the Swift Package Index

## After Initial Publication

- [ ] Gather API feedback from at least one external integration
- [ ] Expand the public results gallery and benchmark table
- [ ] Evaluate optional top-candidate saliency checks only after face
      preference is calibrated
- [ ] Evaluate `bestFrames(in:count:options:)` only after demonstrated demand
- [ ] Evaluate an explicit fast early-exit mode without changing default
      deterministic selection

## Stable Release (`1.0.0`)

- [ ] Meet every criterion in [version-1.0.0.md](version-1.0.0.md)
- [ ] Freeze the public API and document migration from the final beta
- [ ] Reproduce the release quality suite and performance reports
- [ ] Publish release notes and a signed `1.0.0` tag
- [ ] Publish the accompanying MetaFlash article

## Deferred Research

These ideas stay out of active implementation until the shared fixture set can
measure their quality impact and a real consumer demonstrates the need:

- an [automatic profile resolver](automatic-profile-research.md) trained to
  choose the scoring policy that improves poster selection, with genre and
  rendering subcategories retained as dataset and evaluation tags rather than
  premature model outputs;
- native AVFoundation pixel buffers, gated by BGRA/NV12 scoring parity,
  transforms, HDR/color handling, output size, codecs, and platform coverage;
- a low-memory prescan, gated by comparable URL/custom-source scores and final
  actual-time semantics;
- additional transient in-process analysis reuse;
- automatic saliency crops;
- parallel analysis of multiple frames; and
- a dedicated CLI wrapper.

Writing or standardizing a poster timestamp remains an application/container
interoperability experiment tracked in
[Heiter Integration](heiter-integration.md), not a PosterFrameKit 1.x container
responsibility.

Persistent thumbnail caching remains the caller's responsibility. Dedicated
container decoders and application-specific adapters remain outside the
package.
