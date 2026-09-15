# PosterFrameKit Benchmarks

The benchmark executable generates a deterministic, freely reproducible H.264
fixture under `.build/poster-frame-benchmarks` and runs each measured selection
in a separate worker process. Fixture creation is therefore excluded from
runtime and peak-resident-memory measurements.

For quality calibration, the repository also provides a
[versioned fixture manifest and fetcher](Fixtures/README.md). The catalog
combines five checksum-locked, freely licensed animation/live-action sources
with five deterministic generated edge cases. The default fetch creates
silent, bounded 120-second H.264 clips from the downloaded sources under the
ignored `Benchmarks/.fixtures` directory; the quality executable generates its
synthetic entries on demand:

```bash
Scripts/fetch-benchmark-fixtures.py
Scripts/fetch-benchmark-fixtures.py --verify-only
```

The multi-gigabyte HDR `Meridian` and `Sol Levante` masters are cataloged but
deferred and are never downloaded by the default command.

Run a native Apple Silicon release benchmark from the repository root:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --label local \
  --candidates 40 \
  --exclude-midroll \
  --lanes 1,2,3,4 \
  --cold-runs 3 \
  --warm-runs 5 \
  --output Benchmarks/Reports/local.json
```

The report records hardware, OS, architecture, codec, dimensions, frame rate,
duration, candidate count, output size, selected timestamp, score,
end-to-end runtime, selection-scoped sampled RSS, and timings measured directly
at the following boundaries:

- asset metadata loading;
- seek and decode;
- `CGImage` to `CVPixelBuffer` conversion;
- analysis and ranking;
- final result-image creation;
- optional subtitle recognition, including inspected-frame and accurate-fallback
  counts; and
- optional face detection, including inspected-frame counts; and
- optional Vision aesthetics analysis, including inspected-frame counts.

Stage durations are cumulative work. With multiple decoder lanes they overlap,
so they must not be added to infer end-to-end time. Every `processColdRun` uses
a new worker without a selection warm-up. Every `processWarmRun` uses a new
worker and performs one unmeasured selection first. `--cold-runs` and
`--warm-runs` control the two groups independently.

Resident memory is sampled every 2 ms only around the measured selection. Each
run records its starting, sampled-peak, ending, and peak-increase values; the
report also provides medians for both cache groups. These values replace the
old process-lifetime `ru_maxrss` measurement, which could include earlier work.
The harness cannot purge macOS's filesystem cache, so “process cold” does not
claim “disk-cache cold.” Every schema-6 report records this limitation.

A local video may be supplied without adding it to the repository:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --fixture /path/to/video.mp4 \
  --candidates 16 \
  --lanes 1,2,3,4
```

Run separate reports with `--candidates 8`, `16`, `24`, and `40` when comparing
candidate budgets. Keeping one candidate count per report preserves the report
shape and makes reversed run orders straightforward. `--exclude-midroll`
applies the demo's normalized `46–54%` exclusion when a candidate-budget run
should avoid common anime eyecatches or midpoint transitions.

Use the deterministic subtitle-calibration variant to compare the optional
refinement on identical generated content:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --label subtitle-avoidance-on \
  --generated-fixture subtitles \
  --candidates 24 \
  --lanes 4 \
  --avoid-subtitles \
  --subtitle-candidates 8 \
  --subtitle-maximum-penalty 0.08 \
  --warm-runs 5 \
  --output Benchmarks/Reports/subtitle-on.json
```

Omit `--avoid-subtitles` for the paired baseline. The version-3 fixture
contains a lower-third dialogue subtitle, lower-third credits, a clean
control, and a central scene sign. The direct integration test checks their
classification boundary, while paired benchmark reports verify the selected
timestamp and opt-in cost. `score` remains the base metric score;
`subtitlePenalty` and `adjustedScore` describe the refinement result. The
current harness report schema is version 7. See
[Subtitle-Avoidance Calibration](../docs/subtitle-calibration.md).

For detector calibration against real photography and official subtitle text,
prepare the separate checksum-locked paired set and run its focused harness:

```bash
Scripts/fetch-subtitle-calibration-fixtures.py
arch -arm64 swift run -c release PosterFrameKitSubtitleBenchmark \
  --report Benchmarks/.subtitle-results/report.json
```

This evaluates exact Tears of Steel frames as matched clean, English/German
outline, and English boxed variants. Source media, SRT files, and diagnostic
JPEGs remain ignored; the manifest, renderer, labels, and compact JSON evidence
are versioned. It measures the actual subtitle analyzer in isolation and does
not substitute for the process-isolated end-to-end benchmark above.

The paired `m1-pro-macos-15.7.4-subtitle-calibration-v3-{off,on}.json`
reports record the expanded boundary fixture. All runs move from its
dialogue-subtitle frame at `9.833 s` to the eligible scene sign at `19.500 s`.
The warm median increases from `124.70 ms` to `147.19 ms`; two fast text
requests account for `17.30–19.93 ms` of cumulative warm work, and no accurate
fallback is used.

Use a local face-containing video to compare the optional face refinement with
an otherwise identical run:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --fixture /path/to/freely-licensed-video.mp4 \
  --label face-preference-on \
  --candidates 24 \
  --lanes 4 \
  --prefer-faces \
  --face-candidates 8 \
  --face-maximum-bonus 0.04 \
  --warm-runs 5
```

Omit `--prefer-faces` for the paired baseline. Reports include
`faceCompositionBonus`, cumulative `faceAnalysisMilliseconds`, and
`faceAnalyzedFrameCount`. The generated fixture contains no licensed face
imagery, so it is useful for measuring the no-face overhead but not quality.

To inspect every decoded candidate in the five freely licensed core videos,
run the deterministic quality harness with face calibration enabled:

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --deterministic-posterframe \
  --calibrate-faces \
  --candidates 24 \
  --output-directory Benchmarks/.quality-results/face-calibration \
  --report Benchmarks/Reports/local-face-calibration.json
```

`--calibrate-faces` requires `--deterministic-posterframe`, preventing the
normal face preference from warming the detector before evidence capture. The
schema-4 report records both passes, every observation's normalized bounds and
confidence, composition quality, base rank, simulated default preference, and
detection stability. Ignored JPEG contact sheets draw the raw detections for
manual false-positive and miss review. The first pass is the first calibration
pass for that fixture; only the first fixture also includes process-cold Vision
startup. The second pass is warm. See
[Face-Preference Calibration](../docs/face-calibration.md) for the checked
report, review, and paired end-to-end benchmark.

Use the generated fixture to measure the bounded Apple Vision aesthetics stage
without making a quality claim for synthetic content:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --label aesthetic-preference-on \
  --candidates 24 \
  --lanes 4 \
  --prefer-aesthetics \
  --aesthetic-candidates 24 \
  --aesthetic-maximum-adjustment 1 \
  --cold-runs 3 \
  --warm-runs 5 \
  --output Benchmarks/Reports/aesthetic-on.json
```

Omit `--prefer-aesthetics` for the paired baseline. The stage requires macOS
15 or newer. Reports include the raw selected `aestheticScore`,
`isUtilityFrame`, signed `aestheticAdjustment`, cumulative
`aestheticAnalysisMilliseconds`, and `aestheticAnalyzedFrameCount`.

The real-material quality harness compares PosterFrameKit's recommended
Vision-first configuration with pure Vision and the demo's transparent 50/50
hybrid over the same 24 candidates:

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --report Benchmarks/Reports/local-quality.json
```

That command keeps the reviewed five-video baseline stable. Select a generated
edge case directly with `--fixture generated-very-short-single`, or pass
`--include-pending-review` to process all ten active core entries. Pending
fixtures report `acceptable: null` until their ranges are visually reviewed;
they are never treated as automatic failures.

Add `--deterministic-posterframe` when evaluating changes to PosterFrameKit's
base metrics and scoring without the optional face or Vision aesthetics
refinements:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --deterministic-posterframe \
  --include-pending-review \
  --candidates 24 \
  --report Benchmarks/Reports/local-deterministic-quality.json
```

Pure Vision and hybrid results remain in that report as shared-plan context;
only the PosterFrameKit policy switches to the deterministic base ranking.

Pass `--aesthetic-candidates` to hold the 24-position sampling plan constant
while calibrating only the bounded Vision shortlist:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --aesthetic-candidates 8 \
  --output-directory Benchmarks/.quality-results/aesthetic-cap-8 \
  --report Benchmarks/Reports/local-aesthetic-cap-8.json
```

The option requires the default Vision-first policy and rejects combination
with `--deterministic-posterframe` or a cap larger than the sampling count.
Schema-5 reports record the cap separately from the sampling count. Repeat
with `8`, `12`, `16`, and `24`; add
`--include-pending-review` for the generated technical controls. See
[Aesthetic Candidate-Cap Calibration](../docs/aesthetic-calibration.md) for
the checked quality and process-isolated performance matrix.

For profile calibration, `--profile general` or `animation` overrides the
profile declared by every selected fixture. Combine it with
`--deterministic-posterframe` so optional Vision refinements cannot hide the
effect of the profile weights. For example:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --fixture tears-of-steel \
  --profile animation \
  --deterministic-posterframe \
  --output-directory Benchmarks/.quality-results/animation-on-live-action
```

Winner PNGs are written under ignored `Benchmarks/.quality-results`; the JSON
stores relative artifact paths, selected times, component scores, acceptable-
range checks, system metadata, and ranking durations. See
[Initial Quality Evaluation](../docs/quality-evaluation.md) for the reviewed
five-fixture baseline and its intentionally limited claim.

Only generated or freely licensed fixtures and reports suitable for public
reproduction belong in `Benchmarks/Reports`. Local media and its reports remain
uncommitted.

An optional comparison runner exercises FFmpeg's `thumbnail` filter over every
frame of each reviewed downloaded fixture. FFmpeg is a local benchmark tool,
not a package dependency:

```bash
python3 Scripts/run-ffmpeg-thumbnail-comparison.py
```

The runner uses each normalized clip's reported frame count as one thumbnail
batch, writes ignored PNGs for visual review, and records the selected time,
acceptable-range result, complete decoded-frame count, wall time, FFmpeg
version, and process architecture. Runtime comparisons are valid only when the
FFmpeg and PosterFrameKit reports use comparable native architectures; the
checked initial FFmpeg result used an x86_64 binary under Rosetta and is kept as
quality evidence only.

The four paired `m1-pro-macos-15.7.4-candidate-budget-quality-*` and
`m1-pro-macos-15.7.4-candidate-budget-performance-*` reports compare `8`, `16`,
`24`, and `40` candidates. Quality runs cover all ten active catalog entries;
performance runs use the generated 30-second 1280×720 H.264 fixture, four
decoder lanes, midroll exclusion, face preference, and Vision-first aesthetics
with three process-cold and five process-warm workers. The reviewed result and
decision are documented in
[Initial Quality Evaluation](../docs/quality-evaluation.md#candidate-budget-comparison).

The paired `m1-pro-macos-15.7.4-entropy-deterministic-{before,after}.json`
reports isolate the structure-qualified entropy scoring change across all ten
active fixtures. The smooth generated luma ramp no longer wins, while all five
reviewed real-video winners remain unchanged. The paired
`m1-pro-macos-15.7.4-entropy-performance-{before,after}.json` reports use the
generated 30-second fixture, 24 candidates, four decoder lanes, three
process-cold workers, and five process-warm workers. They show no measurable
runtime regression; the full interpretation is documented in
[Initial Quality Evaluation](../docs/quality-evaluation.md#structure-qualified-entropy).

The checked-in `m1-pro-macos-15.7.4-shared-ci-context.json` report records the
accepted Core Image context-reuse optimization. Against the preceding stored
four-lane report, median warm result-image conversion decreased from `11.82 ms`
to `3.18 ms`; warm end-to-end median decreased from `233.63 ms` to `226.56 ms`.
The selected time and score were unchanged. These schema-1 reports predate
selection-scoped RSS sampling, so their process-lifetime peak values are kept
only as historical data.

The paired `m1-pro-macos-15.7.4-subtitle-avoidance-{off,on}.json` reports use
Apple M1 Pro/macOS 15.7.4, native ARM64, a 1280×720 H.264 fixture, 24
candidates, four decoder lanes, three process-cold runs, and five process-warm
runs. The option changed the winner from the subtitle frame at `9.833 s` to a
clean frame at `7.667 s` and
increased the process-warm median from `111.92 ms` to `130.61 ms`. Two leading
frames were recognized in `17.41–20.24 ms` cumulative warm time; no accurate
fallback was needed. Treat this as a reproducible mechanism/cost check, not
multi-genre quality calibration.

The paired `m1-pro-macos-15.7.4-aesthetic-preference-{off,on}.json` reports use
the same hardware, OS, resolution, codec, candidate count, lane count, and run
counts. Enabling the former eight-candidate, `0.05`-cap refinement changed the
generated winner from `7.667 s` to `16.250 s` and increased the process-warm
median from `120.91 ms` to `184.58 ms`. Warm aesthetics analysis took
`55.01–64.34 ms` cumulatively and inspected eight frames. The fixture contains
synthetic patterns, so this validates bounded execution and records opt-in cost
rather than aesthetic quality.

The later `m1-pro-macos-15.7.4-aesthetic-vision-first.json` report measures the
accepted 24-candidate, `1.0`-cap policy against the same checked-in off report.
Its five-run process-warm median is `257.30 ms`, versus `120.91 ms` without
aesthetics. All 24 requests ran and consumed `128.80–159.55 ms` cumulatively in
the warm runs. This is the explicit cost of the quality-first setting; callers
that prioritize latency can leave `aestheticPreference` nil and retain the
deterministic fallback.

The `m1-pro-macos-15.7.4-aesthetic-cap-{quality,performance}-{8,12,16,24}.json`
reports hold sampling, face preference, decoding, and output size constant
while changing only the aesthetics shortlist. The five-video quality matrix
keeps every selection within its reviewed range. The Sintel performance matrix
shows warm medians of `291.63`, `308.34`, `324.89`, and `361.11 ms`; the
quality-first cap remains 24 because the smaller caps exclude one competitive
live-action winner rather than reproducing the full policy exactly.
