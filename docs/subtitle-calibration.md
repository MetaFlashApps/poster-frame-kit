# Subtitle-Avoidance Calibration

Subtitle avoidance is an opt-in ranking refinement, not a general text filter.
Its intended boundary is deliberately narrow:

- burned-in dialogue subtitles and lower-third credits are unwanted poster
  candidates and may receive a penalty;
- clean frames and scene-defining signs outside the lower third remain fully
  eligible; and
- text inside the lower third is inherently ambiguous from a single still, so
  a sign in that region may still look subtitle-like.

This boundary protects useful environmental text instead of treating every
recognized word as a defect. The option remains disabled by default while the
real-material calibration set is small.

## Deterministic Calibration Fixture

The `subtitles` generated-fixture variant is versioned as
`generated-h264-1280x720-30s-subtitle-calibration-v3`. It contains the same six
synthetic base scenes as the standard fixture plus four reproducible text
conditions:

| Time | Condition | Expected classification |
| ---: | --- | --- |
| `9–10 s` | Centered burned-in dialogue subtitle in the lower third | Subtitle-like |
| `14–15 s` | Two lower-third credit lines | Subtitle-like |
| `17.5 s` | Clean control frame | No penalty |
| `19–20 s` | Prominent scene sign in the middle of the image | No penalty |

The integration test decodes those frames from the generated H.264 video and
runs the same Vision analyzer used by PosterFrameKit. It verifies that the two
unwanted lower-third conditions are recognized while both controls remain at
zero likelihood:

```bash
arch -arm64 swift test \
  --filter GeneratedFixtureTests/testSubtitleCalibrationTargetsLowerTextButPreservesSceneSign
```

The end-to-end selection check uses identical 24-candidate runs with the
option off and on:

```bash
arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --generated-fixture subtitles \
  --candidates 24 \
  --lanes 4 \
  --cold-runs 3 \
  --warm-runs 5

arch -arm64 swift run -c release PosterFrameKitBenchmark \
  --generated-fixture subtitles \
  --candidates 24 \
  --lanes 4 \
  --avoid-subtitles \
  --subtitle-candidates 5 \
  --subtitle-maximum-penalty 0.08 \
  --cold-runs 3 \
  --warm-runs 5
```

The checked Apple M1 Pro/macOS 15.7.4 reports use native ARM64, 1280×720 H.264,
24 candidates, four decoder lanes, three process-cold runs, and five
process-warm runs. Every unrefined run selected the dialogue-subtitle frame at
`9.833 s`; every refined run selected the scene-sign frame at `19.500 s`, and
that winning sign received no subtitle penalty.

| Configuration | Cold median | Warm median | Warm text work |
| --- | ---: | ---: | ---: |
| Off | `254.57 ms` | `124.70 ms` | None |
| On | `279.18 ms` | `147.19 ms` | Two fast requests, `17.30–19.93 ms` cumulative |

The accurate fallback was not used. The warm end-to-end difference was
`22.48 ms` (18.0%) on this fixture. See the checked
[`off`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-calibration-v3-off.json)
and
[`on`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-calibration-v3-on.json)
reports. This establishes the desired synthetic boundary, not accuracy across
languages, typography, genres, or real photography.

## Real-Material Calibration

The versioned `tears-of-steel-live-action-subtitles-v1` manifest adds a first
real-photography calibration layer. Its fetcher reuses the checksum-locked
720p Tears of Steel source and downloads the project's official English and
German SRT files. Video and subtitle inputs remain in the ignored fixture
cache:

```bash
Scripts/fetch-subtitle-calibration-fixtures.py
Scripts/fetch-subtitle-calibration-fixtures.py --verify-only

arch -arm64 swift run -c release PosterFrameKitSubtitleBenchmark \
  --report Benchmarks/.subtitle-results/report.json
```

The benchmark decodes 13 exact source timestamps once, then evaluates the same
pixels as a clean control, English outline subtitles, German outline
subtitles, and English subtitles on a translucent box. Official cue timing and
text are used; only rasterization is controlled by the checked renderer. This
produces 52 paired samples. Forty-eight have a reviewed positive or negative
label, while four copies of a holographic lower-third interface remain
explicitly ambiguous and are excluded from recall and specificity.

One clean source frame contains an actual lower-third production credit and is
correctly positive. A central scene title remains eligible. This preserves the
product boundary: lower-third credits are avoidable, while useful text outside
that region is not a defect.

### Measured correction

Vision's fast pass originally missed four small outline samples. Direct
accurate-mode diagnostics found all four, but running accurate recognition on
every candidate would be needlessly expensive. The existing 320-pixel luma
precheck now also looks for a concentrated band of bright, high-contrast
strokes and requests the already-existing accurate retry only when that narrow
signal is present.

| M1 Pro / macOS 15.7.4 | Before | After |
| --- | ---: | ---: |
| Evaluated samples | `48` | `48` |
| True positives | `30` | `34` |
| False negatives | `4` | `0` |
| True negatives | `14` | `14` |
| False positives | `0` | `0` |
| Recall | `88.2%` | `100%` |
| Specificity | `100%` | `100%` |
| Accurate fallbacks | `2` | `6` |

The median analyzer duration was `10.33 ms` before and `9.17 ms` after. Those
single warm in-process passes do not establish a speed improvement; they show
that the additional fallback is bounded to the four formerly missed frames.
The separate process-isolated generated-fixture run still selected the same
`19.500 s` scene sign, inspected two candidates, and used no accurate fallback.
Its subtitle-analysis work remained inside the earlier warm range at
`16.45–17.67 ms`; end-to-end differences between the separate runs are treated
as run variance, not a performance claim.

See the checked
[`before`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-real-material-before.json),
[`after`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-real-material-after.json),
and
[`generated-fixture`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-bright-stroke-fallback.json)
reports. Lowering Vision's minimum text height, automatic language detection,
and the legacy text-rectangle detector were also measured. None produced a
safer improvement on this set, so none of those experiments remains in product
code.

A follow-up process-isolated
[`eight-candidate default`](../Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-default-eight.json)
report preserves the generated fixture's `19.500 s` winner, still analyzes only
two candidates through fast recognition, and uses no accurate fallback. The
higher cap retains up to three additional pixel buffers when subtitle avoidance
is enabled; callers prioritizing memory can still request five explicitly.

## Remaining Evidence

The new set proves the targeted correction on one live-action film, two Latin
script languages, and two controlled render styles. Subtitle avoidance remains
off by default. Before making a broader accuracy claim or changing that
default, add:

- freely licensed 2D and 3D animation with native burned-in subtitles;
- additional fonts, sizes, colors, languages, writing systems, and placements;
- clean dialogue shots with subtitle-like edges and more lower-third signs;
- extreme motion, compression, low resolution, and vertical video; and
- independent review of every positive, negative, and ambiguity label.

Every extension must preserve matched clean controls, source/license
provenance, checksum locks, analyzer-path diagnostics, and runtime evidence.
No threshold or geometry change is accepted from one clip alone.
