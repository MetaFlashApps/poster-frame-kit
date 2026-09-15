# Aesthetic Candidate-Cap Calibration

This document evaluates how many leading candidates PosterFrameKit should pass
to optional Apple Vision image-aesthetics scoring. It uses the repository's
checksum-locked, freely licensed core videos and keeps the sampling plan fixed,
so it measures the refinement shortlist rather than the number of decoded
frames.

## Method

Each quality run planned 24 positions, applied the fixture's declared profile
and `46...54%` midroll exclusion, enabled the default eight-candidate face
preference, and varied only `PosterFrameAestheticOptions.candidateCount` among
8, 12, 16, and 24. Exclusion and timestamp deduplication yielded 22 decoded
candidates per core video. The aesthetic maximum adjustment remained `1.0`, so
Vision supplied the aesthetic base score within each bounded shortlist.

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --aesthetic-candidates 8 \
  --output-directory Benchmarks/.quality-results/aesthetic-cap-8 \
  --report Benchmarks/Reports/m1-pro-macos-15.7.4-aesthetic-cap-quality-8.json
```

The command was repeated for `12`, `16`, and `24`. Passing
`--include-pending-review` also exercised the five deterministic generated
catalog fixtures. They are technical utility, text, short-duration, and coarse-
timestamp controls rather than aesthetic ground truth.

## Quality Results

| Fixture | Cap 8 | Cap 12 | Cap 16 | Cap 24 | Review |
| --- | ---: | ---: | ---: | ---: | --- |
| Morevna Demo | 73.750 s | 73.750 s | 73.750 s | 73.750 s | Same clean character close-up. |
| Big Buck Bunny | 108.000 s | 108.000 s | 108.000 s | 108.000 s | Same expressive character frame. |
| Sintel | 86.583 s | 86.583 s | 86.583 s | 86.583 s | Same strong face frame. |
| Tears of Steel | 35.250 s | 35.250 s | 35.250 s | 86.583 s | Both are useful; the smaller cap gives scene context, while 24 gives a tighter face with an open mouth. |
| Cosmos Laundromat | 90.875 s | 90.875 s | 90.875 s | 90.875 s | Same face-preferred human close-up. |

Every selection remained in its fixture's reviewed acceptable ranges. The
Tears of Steel `35.250 s` frame had post-aesthetic score `0.9453` and pre-
aesthetic base rank 5. The `86.583 s` frame had score `0.9492` and base rank 17,
so no cap below 17 could consider it. The `0.0039` score difference and direct
image inspection do not establish a visible quality improvement for 24, but
the different result prevents claiming strict equivalence.

Generated controls changed at some caps, as expected when synthetic color bars,
flat fields, and text cards are offered to an aesthetics model. Those outputs
confirm bounding behavior and utility exposure, not human aesthetic quality;
they are not used to choose the default.

## Runtime and Memory

The process-isolated matrix used the freely licensed Sintel clip: 120-second
H.264, 1280×544, animation profile, 24 planned and 22 decoded candidates, four
decoder lanes, default face preference, three fresh process-cold workers, and
five separately warmed workers. Measurements were recorded on an Apple M1 Pro
with 32 GiB RAM running macOS 15.7.4. Filesystem cache state was uncontrolled.

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --fixture Benchmarks/.fixtures/clips/sintel-dark-animation.mp4 \
  --candidates 24 \
  --exclude-midroll \
  --lanes 4 \
  --prefer-faces \
  --face-candidates 8 \
  --face-maximum-bonus 0.04 \
  --prefer-aesthetics \
  --aesthetic-candidates 8 \
  --aesthetic-maximum-adjustment 1 \
  --cold-runs 3 \
  --warm-runs 5
```

| Cap | Cold median | Warm median | Warm aesthetic work | Warm peak RSS | Inspected |
| ---: | ---: | ---: | ---: | ---: | ---: |
| `8` | 532.47 ms | 291.63 ms | 42.13 ms | 206.1 MiB | 8 |
| `12` | 537.97 ms | 308.34 ms | 64.44 ms | 217.0 MiB | 12 |
| `16` | 551.98 ms | 324.89 ms | 83.88 ms | 229.0 MiB | 16 |
| `24` | 582.51 ms | 361.11 ms | 115.48 ms | 234.5 MiB | 22 |

Relative to 24, cap 8 reduced the warm median by `69.48 ms` (`19.2%`) and warm
aesthetics work by `73.35 ms` (`63.5%`). It also reduced the recorded warm peak
RSS by 28.4 MiB, although selection-scoped peak increases were close enough
that memory is supporting rather than decisive evidence.

## Decision

Keep 24 as `PosterFrameAestheticOptions`' conservative quality-first default.
The core set is small and one candidate outside every smaller shortlist remains
competitive. Changing the default would silently make deterministic base rank
more influential even though callers requested Vision-first aesthetics.

Document 8 as the explicit latency-first cap. It retained four exact winners,
produced one visually competitive alternative, and delivered a meaningful warm
runtime reduction. Caps 12 and 16 added cost without changing any reviewed
selection relative to 8, so this calibration provides no reason to recommend
them.

The next quality expansion needs more freely redistributable live action, 2D
animation, deliberately plain but useful frames, aesthetic composition
outliers, and multiple independent reviewers. The next performance experiment
should evaluate safe Vision request execution and modern-API parity without
changing this accepted cap policy first.
