# PosterFrameKit – Performance Roadmap to 1.0

This document turns measured bottlenecks and open optimization hypotheses into
an ordered program of work. It does not promise that every experiment will be
accepted. The public [roadmap](roadmap.md) owns product milestones, while this
file owns performance questions, measurement gates, and stop conditions.

Rejected experiments and historical measurements remain in
[Research Findings](research-findings-2026-08.md). Stable-release requirements
remain binding in [Version 1.0.0](version-1.0.0.md).

## Rules for Every Optimization

An optimization is accepted only when all of the following are true:

1. A checked-in or documented before/after benchmark uses identical fixtures,
   options, architecture, build mode, and cache protocol.
2. Selected actual timestamps and score components remain identical unless a
   separately reviewed quality experiment intentionally changes behavior.
3. Cancellation, partial decoder failure, tie-breaking, and optional-stage
   rollback remain covered by deterministic tests.
4. Runtime and selection-scoped resident memory are reported together.
5. The implementation remains bounded and adds no external package dependency.
6. A result outside ordinary run-to-run noise reproduces in reversed run order.

Release measurements use native ARM64 release builds. Each report records chip,
RAM, OS, codec, dimensions, duration, candidate count, decoder lanes, output
size, process-cold runs, process-warm runs, and the uncontrolled filesystem
cache. Stage durations are cumulative work and are never summed into a fake
end-to-end value.

## Current Baseline and Bottlenecks

The accepted M1 Pro/macOS 15.7.4 reports establish these starting points:

- four bounded macOS decoder lanes reduced the 40-candidate generated-fixture
  warm median from `575.95 ms` to `233.63 ms`;
- the 24-candidate deterministic path without aesthetics measured `120.91 ms`;
- the 24-candidate Vision-first path measured `257.30 ms`;
- 24 sequential Vision aesthetics requests consumed `128.80–159.55 ms` in warm
  runs;
- deterministic analysis and ranking consumed approximately `4 ms` for 24
  candidates;
- 24 retained 1280×720 BGRA candidates require approximately `84 MiB` before
  decoder, Vision, Core Image, and result-image overhead; 40 require about
  `141 MiB`.

The important consequence is that base-metric loops are not the next runtime
bottleneck. Current priorities are Vision work, seek/decode behavior, retained
candidate memory, and truthful workflow measurement.

## 0.2 – Measurement and Quality Foundation

### Benchmark structure and regression tests

- [x] Split argument parsing, report schema, fixture generation, coordinator,
      worker, memory sampling, and statistics into focused source files.
- [x] Add tests for benchmark argument validation and overflow-safe medians.
- [x] Register generated standard, subtitle, short-duration, and coarse-seek
      fixtures in the shared manifest instead of maintaining parallel metadata.
- [x] Add report-schema round-trip tests covering every measurement group.
- [ ] Add a command that compares two compatible reports and rejects mismatched
      hardware, fixture, option, or cache protocols before showing deltas.

### Candidate-budget quality matrix

- [x] Run `8`, `16`, `24`, and `40` candidates on every shared quality fixture.
- [ ] Record decoded unique actual frames, winner stability, acceptable-range
      results, subjective review, runtime, and peak memory. The mechanical
      evidence is recorded; pending-review generated fixtures and broader
      human review remain open.
- [x] Keep `24` as the demo default until the shared set justifies another value.
- [x] Treat `8` only as an explicit speed-first candidate until quality evidence
      covers wide shots, faces, subtitles, animation, and live action.

Exit gate: every later performance experiment can run against one versioned
quality catalog and one tested report pipeline.

## 0.3 – Vision Refinement Cost

Vision aesthetics is the largest optional CPU/accelerator stage and therefore
the first runtime experiment after the quality baseline is stable.

### Modern Vision API parity

- [ ] Implement a benchmark-only adapter using
      `CalculateImageAestheticsScoresRequest` while retaining the current
      revision-1 adapter as the control.
- [ ] Compare result scores, utility flags, cancellation latency, cold startup,
      warm inference, and memory.
- [ ] Test one request per candidate and safe sequential request reuse.
- [ ] Adopt the modern adapter only if OS availability, determinism, failure
      semantics, and performance are at least equivalent.

### Bounded parallel aesthetics

- [ ] Add benchmark-only `1`, `2`, and `4` analysis-lane modes. Every lane owns
      its request state; results are restored to candidate order before ranking.
- [ ] Cancel remaining requests on task cancellation or stage failure and prove
      that the complete aesthetic stage still rolls back atomically.
- [ ] Compare the generated fixture and all real-material fixtures in reversed
      lane order.
- [ ] Record cumulative request time, stage wall time, peak concurrency, peak
      memory, selected time, raw Vision score, and final adjusted score.
- [ ] Reject parallelism if Vision serializes internally, end-to-end improvement
      is not repeatable, or memory growth is disproportionate.

### Smaller aesthetic candidate groups

- [x] Compare `8`, `12`, `16`, and `24` aesthetic candidates while holding the
      sampling plan at 24 candidates.
- [x] Review composition outliers, utility frames, faces, and subtitle cases,
      not only acceptable time ranges.
- [x] Retain 24 as the conservative quality-first cap: eight saved `19.2%`
      process-warm time on Sintel and retained four of five reviewed winners,
      but every smaller cap chose a different live-action frame. Document eight
      as an explicit latency-first alternative rather than silently narrowing
      the default shortlist.

Exit gate: the accepted Vision path has a reproducible candidate cap and
execution policy, with no hidden concurrency or memory growth.

## 0.4 – Seeking and Decode Throughput

### Bounded seek tolerance

- [ ] Add benchmark-only tolerances while keeping exact `.zero` seeking as the
      control. Start with `0.1 s`, `0.25 s`, and `0.5 s`, then refine around the
      best measured range.
- [ ] Record requested and actual times, duplicate actual-frame count, failed
      seeks, winner stability, and distance from reviewed acceptable ranges.
- [ ] Test H.264 and HEVC, short and long GOPs, 23.976/24/25/30 fps, very short
      videos, coarse sources, and clips with preferred transforms.
- [ ] Expose a public seek policy only if a real speed-first use case justifies
      behavior that differs from exact selection.

### AVAssetImageGenerator batch API

- [ ] Compare the current persistent four-generator pool with bounded use of
      AVAssetImageGenerator's asynchronous multi-time generation API.
- [ ] Preserve deterministic error attribution, actual-time deduplication,
      cancellation, output sizing, and preferred transforms.
- [ ] Reject the batch path if it buffers without a firm bound or loses the
      current runtime/memory balance.

### Selection-level concurrency

- [ ] Benchmark one, two, and four simultaneous video selections. Per-selection
      four-lane bounds do not create a process-wide bound.
- [ ] Document a recommended caller concurrency for batch thumbnail generation.
- [ ] Consider a package scheduler only if multiple consumers need it and a
      process-wide policy is measurably better than caller-owned throttling.

Exit gate: default exact selection remains deterministic, and any speed mode has
explicit semantics rather than silently returning nearby frames.

## 0.5 – Memory Work

### Retained candidate lifetime

- [ ] Instrument live candidate-buffer count and bytes at collection,
      refinement, result conversion, and release.
- [ ] Verify that buffers are released immediately after each optional stage and
      after the demo comparison coordinator publishes immutable results.
- [ ] Add stress tests for cancellation during collection and every refinement
      stage to catch retained buffers and tasks.

### Low-memory selection

- [ ] Revisit the measured 320-pixel prescan only as a low-memory experiment,
      not as an assumed speed win.
- [ ] Define final winner re-decode and actual-time semantics before coding the
      production path.
- [ ] Require BGRA/NV12 score parity, transforms, HDR/color handling, output-size
      parity, and multiple codecs before acceptance.

Exit gate: peak memory is bounded by documented candidate and concurrency caps.

### Deferred deterministic-core experiments

These experiments start only if Time Profiler shows deterministic analysis and
ranking above 10% of end-to-end time on an accepted configuration, or if a real
consumer needs candidate budgets above the current bound:

- [ ] Compare the current small linear actual-time set with a canonical
      `CMTime` hash key. Require identical coarse-source deduplication and a
      measurable collection-stage win; at 80 or fewer candidates linear search
      may remain cheaper and clearer.
- [ ] Compare full sorting of the bounded leading group with ordered insertion
      or a fixed-size heap. Preserve score/earlier-time ordering and reject a
      more complex structure unless profiling shows collection overhead.
- [ ] Profile histogram, gradient, and luma-resize loops independently before
      testing Accelerate/vDSP or additional SIMD. Require exact metric-boundary
      tests or versioned tolerance rules before accepting floating-point drift.
- [ ] Keep direct NV12 luma analysis in parity tests with packed BGRA paths so a
      future container adapter does not pay an unnecessary color conversion.

Exit gate: no deterministic-core microoptimization is accepted merely because
it improves an isolated loop; it must improve end-to-end runtime without making
the metric contract architecture-dependent.

## 0.6–0.9 – Platform and Release Hardening

- [x] Reproduce the initial benchmark and quality suite on Apple Silicon macOS.
- [ ] Run generated integration fixtures on physical iOS, tvOS, and visionOS
      devices; simulators do not validate decoder or accelerator performance.
- [ ] Measure whether those platforms benefit from more than one decoder lane.
- [ ] Test backgrounding, memory pressure, thermal throttling, and cancellation.
- [x] Record the first green remote run of the checked-in
      continuous-integration workflow covering debug tests, release builds,
      Swift 6.2, DocC, hygiene, and all declared Apple platform builds.
- [ ] Enable branch protection requiring both workflow jobs on the default
      branch.
- [x] Run Thread Sanitizer on candidate collection and optional refinement
      tests; the 2026-09-06 native ARM64 package run completed all 145 tests
      without diagnostics.
- [ ] Profile one external consumer with its real thumbnail size, concurrency,
      container adapter, and caller-owned cache.
- [ ] Freeze public performance-related options only after external API review.

## 1.0 Acceptance

Before the stable tag:

- [ ] Reproduce the final candidate-budget, aesthetics, decode-lane, subtitle,
      and face reports from a clean checkout.
- [ ] Publish current hardware/OS/codec-specific numbers without universal speed
      claims.
- [ ] Confirm no accepted optimization changes deterministic winners outside its
      documented behavior.
- [ ] Confirm memory is proportional to candidate and concurrency bounds, never
      video duration.
- [ ] Confirm the demo labels shared-candidate quality and true end-to-end timing
      as different experiments.
- [ ] Confirm README, DocC, research findings, changelog, and both roadmaps agree.

## Experiments Not to Repeat Without New Evidence

The following already failed to provide a general quality-preserving speed win:

- central 70%-height analysis;
- optimizing the roughly four-millisecond base-analysis loops first;
- progressive sampling as an unconditional replacement;
- the previous native AVAssetReader pixel-buffer prototype;
- the 320-pixel prescan as a universal speed path; and
- unbounded decoder, frame-buffer, or analysis concurrency.

They may return only when a new fixture class, platform constraint, or consumer
requirement invalidates the earlier experiment's assumptions.
