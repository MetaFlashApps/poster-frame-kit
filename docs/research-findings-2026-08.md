# Research Findings – August 2026

This document preserves measured findings from the archived experiment branch
and the later clean rebuild. It is a decision record, not a product roadmap or
a set of universal performance and quality promises. Each section states
whether an experiment was adopted, rejected, or remains deferred; current
package behavior is documented in the README and concept.

## Decoding and Memory

Across six local clips, seeking and decoding accounted for approximately 82%
to 94% of selection time; analysis itself remained below 1%. An experiment
using up to six independent `AVAssetImageGenerator` instances reduced measured
runtime for 40 candidates from 0.29–0.96 seconds to 0.05–0.38 seconds, depending
on the clip: an improvement of roughly 2.3×–6.5×. The selected timestamps did
not change within this sample.

The cost was substantial: for a 1080p run without `outputSize`, observed peak
memory increased from approximately 410 MB to 549 MB. An unbounded buffering
asynchronous stream can retain considerably more memory for larger images.

These figures were measured on an Apple M1 Pro using local material that
cannot be redistributed. They motivate further work but do not meet the
project's reproducibility requirements.

Decision for the rebuild:

1. Parallelism remains an internal AVFoundation property.
2. `PosterFrameSource` receives no batch API without externally confirmed need.
3. Concurrently active decoders and live image buffers are bounded.
4. Two, three, and four lanes are measured against the sequential path.
5. Runtime improvement and peak memory must be convincing together.

The archived 320-pixel prescan was not faster in its initial experiment because
video decoding, rather than scaling, dominated. A later isolated benchmark is
documented below; it confirms that the approach is primarily valuable as a
memory strategy.

### Rebuilt Result

The active branch now contains a dependency-free benchmark with an on-demand
generated H.264 fixture and isolated worker processes. On Apple M1 Pro/macOS
15.7.4, the stored report reduced the warm median from `575.95 ms` on the
sequential baseline to `233.63 ms` with four bounded lanes. The selected time
and score were unchanged, while first-process peak RSS changed from `169.6 MiB`
to `198.9 MiB`.

The adopted implementation is narrower than the archived experiment: it uses
at most four lanes on macOS; other supported platforms remain serialized until
they have reproducible device benchmarks. It adds no unbounded asynchronous
stream and no new `PosterFrameSource` requirement. The report records
process-cold and process-warm states but does not purge the filesystem cache.

### Corrected Measurement Protocol

Schema 4 replaces the single `firstProcessRun` and process-lifetime `ru_maxrss`
value with independent process-cold and process-warm run arrays. Each cold run
uses a fresh worker without a selection warm-up; each warm run uses a fresh
worker and performs one unmeasured selection first. Current resident memory is
sampled every 2 ms only during the measured selection, recording its starting,
peak, ending, and peak-increase values. Fixture creation remains outside every
worker. The OS filesystem cache is shared and uncontrolled, so the report uses
the precise term “process cold” instead of claiming a disk-cold measurement.

This makes runtime and memory groups comparable without pretending that a
warm-up's lifetime high-water mark belongs to the following selection. Older
schema-1 decoder reports remain useful for runtime and winner comparisons, but
their peak-RSS fields are historical rather than selection-scoped evidence.

## Candidate Budgets

The benchmark harness now accepts an explicit candidate count and the demo's
normalized `46–54%` midroll exclusion. With that exclusion, requested budgets
of `8`, `16`, `24`, and `40` produced `8`, `14`, `22`, and `37` analyzed frames
respectively. All measurements used the animation profile, exact seeking,
1280×720 output, and four decoder lanes on Apple M1 Pro/macOS 15.7.4.

On the generated H.264 1280×720 fixture, ten warm runs measured medians of
`58.91`, `107.18`, `133.45`, and `238.57 ms`. First-process peak RSS was
approximately `79.7`, `109.0`, `137.7`, and `189.2 MiB`. The four budgets chose
different timestamps inside the same five-second synthetic scene but produced
the same score, so this fixture demonstrates scaling rather than realistic
quality.

A preliminary local comparison covered six non-redistributable 1080p H.264
animation episodes. Episode
1 used ten warm runs per budget; episodes 2–6 used three. Across the six files,
the median warm times were `373.44`, `635.03`, `974.60`, and `1584.37 ms`.
Relative to `40`, the per-episode median speedups were therefore `4.10×`,
`2.49×`, and `1.61×` for `8`, `16`, and `24`; their median time reductions were
75.6%, 59.9%, and 38.0%. Median first-process peak RSS was `66.8`, `88.0`,
`111.6`, and `142.5 MiB`.

The runtime and memory trend was consistent, but quality was not monotonic.
Every budget sampled a different uniform grid and consequently selected a
different timestamp in every local episode. In a manual contact-sheet review,
`24` was the most consistently reasonable small budget. Eight was surprisingly
competitive but occasionally chose weak wide compositions. Sixteen produced
three conspicuously weak results in this small set: an extreme eye close-up, a
rear-view composition, and a close-up of a handheld device. These observations
use copyrighted local material, are subjective, and are not a publishable
quality claim.

The important design finding was that the current uniform plans are not nested:
raising the budget does not retain the candidates from a smaller budget. That
made the raw quality comparison unnecessarily unstable.

### Rejected Progressive Schedule Prototype

A temporary prototype repeatedly selected the midpoint of the widest remaining
allowed interval. Larger `8`, `16`, `24`, and `40` budgets retained all
lower-budget timestamps, and final requests were sorted chronologically before
they reached the decoder lanes. With the `46–54%` exclusion it replenished
omitted positions, so the four progressive budgets analyzed `8`, `16`, `24`,
and `40` frames versus uniform's `8`, `14`, `22`, and `37`.

Temporary schema-4 reports on Apple M1 Pro/macOS 15.7.4 used the generated
30-second 1280×720 H.264 fixture, four decoder lanes, three process-cold runs,
and five process-warm runs. Progressive selected `5.250 s` with score `0.345751`
at all four budgets. Uniform selected four different timestamps with score
`0.345651`.
Process-warm medians for progressive were `37.74`, `77.19`, `109.70`, and
`189.40 ms`; uniform measured `49.22`, `78.42`, `108.80`, and `187.46 ms` while
analyzing fewer frames at the last three budgets. Selection-scoped cold peaks
for progressive were `75.3`, `108.3`, `150.6`, and `190.0 MiB`; uniform measured
`76.1`, `105.4`, `139.3`, and `182.1 MiB`.

A directional comparison on the same six non-redistributable local episodes
reduced budget-to-budget winner changes from 18/18 with uniform to 7/18 with
progressive. Four of six progressive 24-candidate winners remained the winner
at 40. Median process-warm runtime was nevertheless approximately 3.9%, 24.2%,
11.9%, and 11.8% higher at 8, 16, 24, and 40. Some of that cost comes from
replenishing excluded candidates, but the result is not a universal speed win.

The prototype and its benchmark hook were therefore removed from the package.
Only this research conclusion is retained. Until a freely reproducible quality
set justifies revisiting the design, `24` remains the safer provisional reduced
budget and `8` belongs only in an explicitly speed-first experiment.

## Native Pixel Buffers and Result Rendering

A direct `AVAssetReaderTrackOutput` prototype requested NV12 pixel buffers,
kept one random-access reader per decoder lane, and therefore avoided the
current per-candidate `CGImage` to BGRA copy. Combined with a reused
`CIContext`, a five-run warm median on the generated H.264 1280×720 fixture
decreased from `226.6–227.1 ms` to `119.8 ms`; first-process peak RSS decreased
from approximately `185–188 MiB` to `42 MiB`. The selected `9.333 s` timestamp
was unchanged.

The result did not generalize to a local 23.976 fps animation H.264 clip. Two
reversed 15-run batches measured `442.9–444.0 ms` for `AVAssetImageGenerator`
and `452.7–453.0 ms` for the native reader, making the prototype 2.0–2.3%
slower. First-process peak RSS nevertheless decreased from approximately
`137–140 MiB` to `40 MiB`, and both paths selected `640.473 s`.

NV12 analysis also changed the score from `0.46318` to `0.44400` on that local
clip because the existing display-ready BGRA path and native video-range luma
do not produce format-identical metrics. A complete implementation additionally
needs preferred-transform, HDR/color, output-size, codec, cancellation, and
supported-platform parity. The benchmark-only decoder and CLI hook were
removed. Native decoding remains promising primarily for memory, but it will
not replace the current path until cross-format quality fixtures and multiple
codecs show a repeatable overall win.

The independent `CIContext` reuse was retained. On the generated fixture it
reduced median warm final-image conversion from `11.82 ms` to `3.18 ms` and the
warm end-to-end median from `233.63 ms` to `226.56 ms`, without changing the
selected time or score. The before-and-after reports are versioned under
`Benchmarks/Reports`.

## Two-Stage CGImage Prescan

Three internal benchmark-only pipelines were compared: the current
`AVAssetImageGenerator` to BGRA pixel-buffer path, direct full-size `CGImage`
analysis, and a 320-pixel-long-edge `CGImage` prescan followed by one full-size
decode of the winner. All variants used 40 candidates, four decoder lanes,
exact seeking, an animation profile, and a 1280×720 requested result. The
temporary pipeline switch and alternate decoder were removed after the
measurement.

Direct full-size `CGImage` analysis was rejected after the initial run. It was
slower on the generated fixture and selected `5.500 s` instead of the baseline
winner at `9.333 s`. It therefore offered neither performance nor selection
parity.

The 320-pixel prescan was measured in two reversed 15-run batches on Apple M1
Pro/macOS 15.7.4. On the generated H.264 1280×720 fixture, its warm median was
`181.91–187.57 ms`, compared with `197.21–200.31 ms` for the current path: a
4.9–9.2% improvement. First-process peak RSS decreased from approximately
`189–196 MiB` to `25 MiB`. Both paths selected `9.333 s`, although the score
changed slightly from `0.34565` to `0.34596`.

On the local 23.976 fps animation H.264 1080p clip, the prescan selected the same
`640.473 s` frame but was 1.9–3.0% slower: `464.31–470.60 ms`, compared with
`450.58–461.96 ms` for the current path. Peak RSS nevertheless decreased by
about 73%, from `142–147 MiB` to `38–39 MiB`. Its score changed from `0.46318`
to `0.45499`. The local clip cannot be redistributed and is not a release
benchmark.

The memory result is large enough to justify a later low-memory experiment,
but the implementation is not adopted yet. A production path must preserve
comparable scoring between URL and custom decoders, define the actual-time
semantics of the final re-decode, and pass cross-format, output-size, and
quality fixtures before it can replace the current
pipeline or become an option.

## Analysis Region and Entropy

A central horizontal 70% strip was measured on Apple M1 Pro/macOS 15.7.4 with
the generated H.264 1280×720 fixture, 40 candidates, four decoder lanes, and 15
warm process runs per variant. It reduced analyzed pixels from `576,000` to
`403,200` and median direct analysis time from `6.18–6.43 ms` to
`4.50–4.73 ms`, a 26–27% reduction. The two reversed batches did not show a
repeatable end-to-end gain: one favored the strip by 3.3%, while the other made
it 0.8% slower, with overlapping decode variability. The synthetic winner also
changed from `9.333 s` to `5.500 s` despite nearly equal scores.

On the local animation 1080p H.264 clip, the same experiment reduced median direct
analysis from `8.28 ms` to `5.44 ms` but made the five-run warm end-to-end
median 1.8% slower. It selected the same `640.473 s` frame; the local clip and
report are not redistributed. The experimental hook was removed after the
measurement. Public selection continues to analyze the full frame and return
it uncropped.

The generated material also exposed a weakness in the current entropy signal.
With the animation profile, a linear grayscale gradient reached entropy
`0.915`, sharpness `0.009`, and colorfulness `0.0`. Color bars reached `0.375`,
`0.115`, and `0.691`; nevertheless, the resulting score was approximately
`0.406` versus `0.374` in favor of the gradient. An evenly populated histogram
has high mathematical entropy but is not automatically a good poster frame.
The entropy weight therefore needs review against realistic fixtures.

## Benchmark Lessons

The archived harness generated eight deterministic H.264 and HEVC clips with
acceptable selection windows. This is a useful foundation but not yet a
quality benchmark: the patterns are simple, several required fixture classes
are missing, and manifest data was duplicated in Swift and JSON.

The following measurement methods will not be retained:

- “decode time” calculated as the end-to-end median minus separately measured
  analysis,
- global `ru_maxrss` after fixture generation as the memory cost of one
  selection, and
- exclusively warm runs without an explicitly reported cache state.

The new harness needs one manifest source of truth, its own tests, direct stage
measurements, cold and warm runs, and memory figures attributable to each
selection. Stored before-and-after reports are part of accepting a performance
change.

## Subtitle Detection

A local experiment examined 40 top candidates from five episodes. Vision's
fast mode agreed with `accurate` in 37 cases, missed text twice, and reported
text once on a supposedly clean frame. One missed frame was the leading
candidate. Changes to minimum text height and language correction did not fix
the issue. Locally, `accurate` required roughly 83 milliseconds per inspected
frame.

In a further sample from seven anime episodes, four leading frames containing
subtitles changed to a subtitle-free candidate after a capped penalty. The
relevant base-score gaps ranged approximately from `0.0003` to `0.0076`;
observed penalties ranged from `0.0156` to `0.0695`. A maximum of `0.08` was
sufficient for this sample and less dominant than the initially tested value
of `0.15`.

These data are one-sided and not freely reproducible. They do not determine
default behavior or support broad quality claims. They did establish the
failure semantics and bounded re-ranking shape.

A later native ARM64 microbenchmark on Apple M1 Pro/macOS 15.7.4 used three
1280×720 still images and a bottom-third Vision region of interest. Fast text
recognition took `2.21–2.85 ms` per request, accurate recognition took
`46.71–67.11 ms`, and full-frame fast recognition took `16.55–22.79 ms` in
that isolated process. The lower-third fast request detected text in both
subtitle examples and none in the clean example. This tiny local set cannot
replace the earlier miss data, but it supports fast recognition as a first
pass rather than paying accurate cost unconditionally.

The implemented adapter consequently uses fast lower-third recognition first.
When it returns no text, a cheap luma edge-band heuristic can trigger one
accurate retry; the heuristic never assigns a penalty itself. Only a small
leading group is inspected, the penalty remains capped and separate from the
base score, thresholds and geometry weights remain internal, any detector
error discards the entire optional re-ranking, and cancellation is never
treated as an empty result.

The versioned `generated-h264-1280x720-30s-subtitles-v2` fixture and paired
reports make the mechanism and runtime cost reproducible. On Apple M1 Pro,
macOS 15.7.4, ARM64, 1280×720 H.264, 24 candidates, four decoder lanes, three
process-cold workers, and five process-warm workers per variant, disabled
subtitle avoidance selected the
generated subtitle frame at `9.833 s` with a `111.92 ms` warm median. Enabling
the default five-candidate, `0.08`-cap policy selected the clean equivalent at
`7.667 s` with a `130.61 ms` median. Score-based early termination still
inspected only two frames, spent `17.41–20.24 ms` in cumulative warm subtitle
analysis, and did not invoke the accurate fallback. The 16.7% median overhead
is an opt-in cost on this single synthetic fixture, not a universal estimate.

A separate local anime-episode regression had subtitles on each of its three
highest base-score candidates and a clean fourth candidate. A three-candidate
limit therefore could not change the result. Raising the default limit to five
selected that clean fourth candidate and inspected four frames; the same score
bound prevents the larger safety margin from becoming unconditional work. The
source video is not redistributable, so the deterministic four-candidate unit
test captures the ranking failure while the generated fixture remains the
published benchmark.

Early termination is valid because a penalty can only make a candidate worse.
Unit tests compare it with complete evaluation and cover ties, a detector
failure after a successful call, and cancellation during the final call.

## Demo Comparisons

Running Vision against the same already decoded candidates is a fair comparison
of ranking decisions. It is not an end-to-end speed comparison with
PosterFrameKit because only PosterFrameKit's time includes video decoding. The
demo therefore labels Vision's duration as ranking-only.

On the research branch, the demo retained up to 40 BGRA candidates at
1280×720, approximately 141 MiB before decoder and image copies. The rebuilt
demo now scopes that candidate set to one comparison task and presents its
stages explicitly, but orchestration still lives in `DemoViewModel`. Moving the
workflow into a dedicated coordinator and verifying prompt buffer release
remain cleanup work rather than completed architecture.

## Vision Aesthetics Library Refinement

Apple exposes image-aesthetics scoring through
[`VNCalculateImageAestheticsScoresRequest`](https://developer.apple.com/documentation/vision/vncalculateimageaestheticsscoresrequest)
on macOS 15+, iOS 18+, tvOS 18+, and visionOS 2+. Its overall score ranges from
`-1` to `1`; the accompanying utility flag describes useful but less memorable
imagery and is already reflected in the overall score. Apple's
[video-thumbnail sample](https://developer.apple.com/documentation/vision/generating-aesthetically-pleasing-thumbnails-from-video-assets)
confirms that the request is intended for this kind of bounded candidate
ranking.

The first implementation kept Vision as an explicit, disabled-by-default
bounded refinement. Revision 1 analyzed at most eight leading candidates,
mapped the raw score to a signed adjustment capped at `0.05`, and preserved the
preceding ranking on unsupported systems or analysis errors.

The checked-in schema-6 pair uses Apple M1 Pro, macOS 15.7.4, native ARM64, the
generated 30-second 1280×720 H.264 fixture, 24 candidates, four decoder lanes,
three process-cold workers, and five process-warm workers. The disabled median
was `120.91 ms`; the default refinement median was `184.58 ms`, with eight
Vision requests taking `55.01–64.34 ms` cumulatively in warm runs. The selected
time changed from `7.667 s` to `16.250 s`; that frame's base score was
`0.32905`, raw aesthetics score `0.45483`, and applied adjustment `0.02274`.
Synthetic patterns cannot validate aesthetic taste, so the pair established
mechanism, bounds, and opt-in cost only. The later checksum-locked five-fixture
comparison in [Initial Quality Evaluation](quality-evaluation.md) found pure
Vision stronger than the 50/50 hybrid for the clearest composition failures.
The accepted configuration therefore aligns the aesthetic base with Vision
across at most 24 candidates while retaining separate face/subtitle effects and
the deterministic fallback.

## Retired Profile Presets

Before the first public release, the provisional `liveAction` and `screencast`
cases were tested with a deterministic profile override. The native ARM64
release harness used the same 24-position plan on the only reviewed real
live-action fixture available at the time:

| Override | Selected time | Base score | Initial inspection |
| --- | ---: | ---: | --- |
| `general` | 65.208 s | 0.46866 | Busy multi-layer VFX composition |
| `animation` | 39.542 s | 0.44121 | Clear single-person street composition |
| `liveAction` | 65.208 s | 0.53577 | Same busy composition as `general` |
| `screencast` | 39.542 s | 0.44376 | Same clear composition as `animation`; not screencast evidence |

All four timestamps fell inside deliberately broad acceptable ranges, but
visual inspection found that `liveAction`'s `0.40` entropy weight amplified the
busier VFX frame rather than improving photographic composition. There was no
reviewed screencast fixture at all, so its distinct weights had no defensible
quality basis.

Both cases and their internal weights were removed rather than publishing
placeholders. This does not remove support for live-action videos or screen
recordings: `general` remains the balanced default, `animation` is explicit,
and `custom` retains caller-controlled weights. A future preset requires
multiple freely reproducible fixtures and a demonstrated advantage over those
existing choices.

## Decision Summary

The rebuild retained bounded macOS decoder parallelism, one shared immutable
`CIContext`, normalized exclusion ranges, the visual-noise penalty, and the
bounded subtitle, face-composition, and Vision aesthetics refinements.
Progressive sampling, native pixel-buffer decoding, the 320-pixel prescan, and
central-strip analysis were removed after they failed to produce a general
quality-preserving performance win.

The versioned, freely reproducible fixture manifest and first quality harness
now provide that calibration base. Candidate-budget changes, entropy
reweighting, any future profile expansion, and additional optional scorers
still require evidence from it rather than isolated examples.
