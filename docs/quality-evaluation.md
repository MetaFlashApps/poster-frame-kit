# Initial Quality Evaluation

This document records the first reproducible real-material comparison. It is a
small calibration baseline, not a claim that one ranking policy wins for every
genre or video.

## Method

The quality harness reads the checksum-locked core fixtures from
`Benchmarks/Fixtures/manifest.json`. Each 120-second clip uses 24 planned
candidates, the fixture's declared profile, and the demo's `46...54%` midroll
exclusion. Exclusions reduce the decoded set to 22 candidates.

It records one neutral baseline and compares three policies over the shared
candidate plan:

1. **Fixed midpoint** — an independent exact-tolerance decode requested at 50%
   of the fixture duration, outside the candidate plan and its exclusions.
2. **PosterFrameKit quality configuration** — an explicitly enabled face
   preference with its eight-candidate default, followed by the recommended
   24-candidate Vision-first aesthetic preference.
3. **Vision** — the highest raw Apple Vision image-aesthetics score.
4. **Hybrid** — an equal blend of PosterFrameKit's base score and Vision's
   normalized score, matching the demo comparison.

The harness writes relative baseline/winner-image paths and complete score
evidence to the schema-3 JSON report. Generated PNGs remain ignored because
they can be reproduced from the licensed fixtures. An explicit gallery output
path additionally writes 80%-quality JPEG pairs suitable for publication.

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --gallery-directory docs/assets/results-gallery \
  --report Benchmarks/Reports/m1-pro-macos-15.7.4-quality.json
```

Manifest schema 2 also registers five deterministic generated fixtures for
patterns, subtitle/credit/sign controls, one- and three-second videos, and
coarse long-GOP timestamps. They are created on demand by the shared Swift
generator and are currently marked `pending-human-review`. The default command
above therefore
continues to evaluate only this document's reviewed five-video baseline. A
generated fixture can be exercised explicitly with `--fixture <id>`, while
`--include-pending-review` runs the expanded ten-fixture technical catalog.
Pending results use `acceptable: null`; they do not become quality assertions
until their ranges have been reviewed.

## Environment

- Apple M1 Pro, 10 logical processors, 32 GiB RAM
- macOS 15.7.4 (24G517)
- native ARM64 release build
- five silent H.264 fixtures, each 120 seconds and at most 1280×720
- warm filesystem state was not controlled

The recorded durations describe this single diagnostic run. PosterFrameKit's
capture duration includes video decoding and its configured refinements;
`visionAnalysisMilliseconds` measures a second in-memory Vision pass used to
construct the comparison columns. They are not competing end-to-end timing
figures.

A separate generated-fixture performance report measures the recommended
24-candidate policy at a `257.30 ms` process-warm median, versus `120.91 ms`
with aesthetics disabled on the same M1 Pro configuration. This quality mode
is intentionally explicit rather than free; the deterministic fallback remains
the latency-first configuration.

## Reviewed Results

| Fixture | Fixed 50% | PosterFrameKit | Vision | Hybrid | Initial visual review |
| --- | ---: | ---: | ---: | ---: | --- |
| Morevna Demo | 59.958 s | 73.750 s | 73.750 s | 95.125 s | The midpoint is a credit frame; PosterFrameKit selects a clean character close-up. Hybrid tells a clearer two-character story, but the PosterFrameKit/Vision close-up is still strong. |
| Big Buck Bunny | 59.958 s | 108.000 s | 108.000 s | 108.000 s | The midpoint is usable, while all ranked policies agree on a clearer expressive character frame. |
| Sintel | 59.958 s | 86.583 s | 86.583 s | 86.583 s | The midpoint is a distant wide shot; all ranked policies agree on the strong face frame. |
| Tears of Steel | 59.958 s | 86.583 s | 86.583 s | 35.250 s | The midpoint centers a machine; PosterFrameKit/Vision select a stronger human close-up, while hybrid chooses a usable wider character shot. |
| Cosmos Laundromat | 59.958 s | 90.875 s | 26.708 s | 9.583 s | The midpoint is a valid sheep close-up. PosterFrameKit's face bonus promotes a clean human close-up; Vision's alternate sheep close-up is also strong, while hybrid is partially occluded. |

All 15 ranked selections fall inside their fixture's deliberately broad
acceptable time ranges. Three of five fixed midpoints do; the Morevna credit
frame and Sintel wide shot sit outside the reviewed ranges. The ranges catch
major regressions but do not establish the preferences above; that judgment
comes from a single documented visual review. The checked-in
[results gallery](../README.md#results-gallery) exposes the midpoint and
PosterFrameKit pairs, while the ignored local matrix retains Vision and hybrid
diagnostics.

## Candidate Budget Comparison

The same native ARM64 release harness was repeated with `8`, `16`, `24`, and
`40` planned candidates. Each run included all ten active catalog entries; the
five generated fixtures remain technical checks with pending human review, so
the quality assessment below is limited to the five reviewed videos. The
`46...54%` exclusion and actual-time deduplication reduced the decoded counts
for those videos to `8`, `14`, `22`, and `37`, respectively.

Runtime was measured separately on the generated 30-second 1280×720 H.264
fixture. Each configuration used four decoder lanes, the animation profile,
the same midroll exclusion, the default eight-candidate face preference, and
Vision-first aesthetics capped at 24 candidates. Three fresh process-cold and
five process-warm workers were recorded per budget; the run order was `8`,
`40`, `16`, `24` to avoid a simple ascending thermal-order bias.

| Planned candidates | Reviewed selections in range | Warm median | Cold median | Warm peak RSS | Visual review |
| ---: | ---: | ---: | ---: | ---: | --- |
| `8` | 4/5 | 141.83 ms | 398.54 ms | 158.8 MiB | Strong speed-first set; Morevna is usable but busier and outside its reviewed range. |
| `16` | 4/5 | 205.27 ms | 416.63 ms | 232.8 MiB | Morevna selects a visibly blurred composition; the larger budget is not a consistent quality gain over 8. |
| `24` | 5/5 | 277.96 ms | 480.59 ms | 284.2 MiB | The only budget without a clear reviewed-set outlier; all five selections are strong and in range. |
| `40` | 4/5 | 363.46 ms | 564.19 ms | 312.6 MiB | Morevna selects a black project title card while requiring the most time and memory. |

The acceptable ranges are deliberately broad regression signals rather than
automatic aesthetic judgments. The ignored winner matrix was therefore
inspected directly: Big Buck Bunny was stable across every budget; Sintel,
Tears of Steel, and Cosmos produced useful alternatives; Morevna exposed the
decisive blur and title-card failures at 16 and 40.

The raw schema-3 quality reports and schema-7 process-isolated performance
reports are stored under `Benchmarks/Reports` with the
`m1-pro-macos-15.7.4-candidate-budget-` prefix. They record the complete system,
configuration, score, timing, and memory evidence.

## Structure-Qualified Entropy

The deterministic policy previously selected the smooth grayscale ramp at
`7.667 s` in `generated-patterns`. Its global luma histogram occupied many
bins, producing high raw Shannon entropy despite almost no spatial structure.
An isolated synthetic test reproduced the same failure across every built-in
profile.

The scorer now preserves the public raw entropy metric but limits only its
weighted contribution while coherent Tenengrad structure is nearly absent.
Visual noise reduces that structural confidence so static-like energy cannot
validate its own entropy. The transition reaches the unmodified raw entropy
contribution at ordinary edge strength; it does not add another image-analysis
pass.

With the correction, the deterministic generated-pattern winner moves from the
smooth ramp at `7.667 s` (`0.34565`) to the structured checkerboard at
`16.250 s` (`0.32905`). All five reviewed deterministic real-video winners and
their acceptable-range results remain unchanged. The recommended Vision-first
PosterFrameKit winner also remains identical on all five videos, including the
face-preferred Cosmos selection.

The paired generated-fixture performance reports use 24 candidates, four
decoder lanes, three process-cold workers, and five process-warm workers. Warm
analysis-and-ranking median changed from `3.63 ms` to `3.41 ms`; warm
end-to-end median changed from `127.63 ms` to `103.74 ms`. These small runs do
not establish a speed improvement, but they show no measurable regression from
the constant-time scoring arithmetic.

## Aesthetic Candidate-Cap Comparison

The Vision-first shortlist was calibrated independently from the sampling
budget by keeping 24 planned positions, the fixture profile, midroll exclusion,
default face preference, output size, and `1.0` maximum aesthetic adjustment
constant. Caps of `8`, `12`, `16`, and `24` were run across all five reviewed
videos. All 20 selections remained in their broad acceptable ranges.

Four fixtures produced the exact same winner at every cap. Tears of Steel used
`35.250 s` at caps 8, 12, and 16, then changed to `86.583 s` at 24 because that
candidate ranked 17th before aesthetics. Direct inspection found both usable:
the smaller-cap result is a contextual side-profile composition, while the
24-cap result is a tighter face shot with a momentarily open mouth. Vision's
normalized scores differ by only `0.0039` (`0.9453` versus `0.9492`). This is
not sufficient evidence that the broader result is universally better, but it
also means the policies are not equivalent.

Process-isolated performance used the freely licensed 120-second Sintel H.264
fixture at 1280×544, 24 planned and 22 decoded candidates, four decoder lanes,
the animation profile, default face preference, three process-cold runs, and
five process-warm runs on the documented M1 Pro/macOS 15.7.4 host.

| Aesthetic cap | Cold median | Warm median | Warm aesthetic work | Warm peak RSS | Winner |
| ---: | ---: | ---: | ---: | ---: | ---: |
| `8` | 532.47 ms | 291.63 ms | 42.13 ms | 206.1 MiB | 86.583 s |
| `12` | 537.97 ms | 308.34 ms | 64.44 ms | 217.0 MiB | 86.583 s |
| `16` | 551.98 ms | 324.89 ms | 83.88 ms | 229.0 MiB | 86.583 s |
| `24` | 582.51 ms | 361.11 ms | 115.48 ms | 234.5 MiB | 86.583 s |

Eight saves `69.48 ms` (`19.2%`) process-warm end to end and `73.35 ms`
(`63.5%`) of warm aesthetics work relative to 24 in this configuration. Twelve
and sixteen add cost without recovering the differing live-action winner. The
default therefore remains 24 as the conservative quality-first policy, while
eight is now a measured explicit latency-first option. Complete method,
generated-control observations, commands, and limitations are in
[Aesthetic Candidate-Cap Calibration](aesthetic-calibration.md).

## Decision

The initial set supports Vision-first rather than the 50/50 hybrid as the
recommended quality configuration on macOS 15+, iOS 18+, tvOS 18+, and
visionOS 2+. Vision fixed the clearest composition failures from the
deterministic metrics, while PosterFrameKit's bounded face bonus improved the
Cosmos result without overturning the other four Vision winners.

`PosterFrameOptions.aestheticPreference` remains explicit because it adds
OS-versioned work and cannot produce a platform-independent deterministic
score. When Vision aesthetics is unavailable or throws, PosterFrameKit keeps
the preceding deterministic face/subtitle/base ranking. That fallback remains
the supported behavior for macOS 13–14, iOS/tvOS 16–17, and visionOS 1.

The candidate comparison promotes `24` from a provisional Demo choice to the
documented quality-first budget and retains `8` as the explicit speed-first
choice. It does not yet change `PosterFrameOptions`' package default: these
quality runs intentionally enabled optional face and Vision aesthetics
refinements, while the default package configuration enables neither. A
default behavior change requires a corresponding deterministic-base comparison
or a deliberate decision to redefine the default quality policy.

Before a public quality claim, this evaluation still needs more 2D animation,
stylized and grouped faces, no-face scenes, intentionally plain utility frames,
subtitles, screencasts, live-action lighting, and multiple independent human
reviewers.

Subtitle detection now also has a focused paired
[real-material calibration](subtitle-calibration.md#real-material-calibration).
It reuses checksum-locked Tears of Steel frames with official English and
German cues, but deliberately remains separate from this winner-level quality
matrix: it measures recognition boundaries, not the overall aesthetic ranking.

The same five source videos now also have a candidate-level
[face-preference calibration](face-calibration.md). It records all 110 decoded
frames rather than only the selected winners, documents the precision-oriented
detector-confidence gate, and separates visual evidence from the paired
process-isolated runtime measurement. The normal recommended five-video
quality run retained every previously documented winner after that change.

The retired pre-release `liveAction` and `screencast` profile experiment and
its measurements remain documented in
[Research Findings](research-findings-2026-08.md#retired-profile-presets).
The remaining public scoring choices are `general`, `animation`, and the
caller-defined `custom` profile.

## FFmpeg Thumbnail Comparison

FFmpeg 7.1's `thumbnail` filter was run over all 2,880 frames of each reviewed
120-second fixture as one batch. This differs fundamentally from
PosterFrameKit's bounded 24-position plan, which decoded 22 unique frames after
midroll exclusion. The optional runner and its parser tests make the comparison
reproducible without adding FFmpeg to the package:

```bash
python3 Scripts/run-ffmpeg-thumbnail-comparison.py
```

| Fixture | FFmpeg time | In reviewed range | Initial visual review |
| --- | ---: | ---: | --- |
| Morevna Demo | 110.625 s | Yes | Clear group composition |
| Big Buck Bunny | 23.167 s | No | Foreground character is motion-blurred |
| Sintel | 14.625 s | No | Fast action frame with an obscured subject and no clear face |
| Tears of Steel | 70.750 s | Yes | Usable two-person composition, but one face is foreground-obscured |
| Cosmos Laundromat | 110.625 s | Yes | Dark, tightly occluded sheep close-up |

FFmpeg lands inside three of five broad acceptable ranges, versus five of five
for the recorded PosterFrameKit quality configuration. Direct image inspection
shows meaningful blur or occlusion in three FFmpeg selections. This supports
the bounded quality approach but remains one reviewer's judgment on a small
set, not a universal superiority claim.

The checked report was produced on an Apple M1 Pro/macOS 15.7.4 host, but the
installed FFmpeg and Python binaries ran as x86_64 under Rosetta. Its 2.28–2.95
second wall times are therefore not compared numerically with PosterFrameKit's
native ARM64 timings. A native-architecture repeat remains necessary before
making a speed claim.
