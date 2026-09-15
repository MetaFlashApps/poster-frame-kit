# Face-Preference Calibration

This document records the first candidate-level calibration of PosterFrameKit's
optional face preference. It uses the checksum-locked, freely licensed core
videos and is deliberately narrower than a general face-detection quality
claim.

## Method

The quality harness decoded the normal 24-position plan with the fixture's
declared profile and the Demo's `46...54%` midroll exclusion. This yielded 22
actual candidates per video and 110 inspected frames in total. Face preference
and aesthetics were disabled during capture so neither could pre-warm or alter
the deterministic base ranking.

Every retained pixel buffer was passed twice through the package's actual
revision-3 Vision adapter and actual composition scorer. The schema-4 report
records raw normalized bounds, Vision confidence, base rank, composition
quality, per-candidate duration, detection stability, and the winner produced
by the default eight-candidate, `0.04`-maximum-bonus policy. Ignored JPEG
contact sheets were then inspected for true faces, obvious false detections,
and misses.

```bash
Scripts/fetch-benchmark-fixtures.py --verify-only
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --deterministic-posterframe \
  --calibrate-faces \
  --candidates 24 \
  --output-directory Benchmarks/.quality-results/face-calibration \
  --report Benchmarks/Reports/m1-pro-macos-15.7.4-face-calibration.json
```

The second pass is warm. The first pass means the first calibration pass for
that fixture, not a fresh process; only Morevna, the first fixture, also pays
process-cold Vision startup. End-to-end process-cold and process-warm cost was
therefore measured separately.

## Candidate-Level Results

| Fixture | Raw detected frames | Scored frames | Raw faces | Base winner | Face-preferred winner | First / warm pass |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Morevna Demo | 2 / 22 | 2 / 22 | 3 | 99.417 s | 99.417 s | 689.88 / 153.87 ms |
| Big Buck Bunny | 0 / 22 | 0 / 22 | 0 | 108.000 s | 108.000 s | 129.27 / 125.66 ms |
| Sintel | 8 / 22 | 7 / 22 | 8 | 13.875 s | 86.583 s | 159.45 / 146.83 ms |
| Tears of Steel | 16 / 22 | 7 / 22 | 19 | 65.208 s | 65.208 s | 176.68 / 172.88 ms |
| Cosmos Laundromat | 5 / 22 | 3 / 22 | 5 | 9.583 s | 9.583 s | 150.62 / 143.44 ms |

All raw bounds and confidence values were identical across both passes.
“Scored” means a detection passed confidence, size, validity, and composition
eligibility; it does not mean that the candidate won.

The contact-sheet review found:

- Morevna had no obvious false detection, but Vision missed several clear,
  strongly stylized faces. This is the most important 2D-animation limitation.
- Big Buck Bunny produced no human-face detection despite prominent animal
  faces, making it a useful incidental non-human control.
- Sintel's detections were visually credible, and preference moved the
  deterministic animation winner from a weak action frame at `13.875 s` to a
  strong face frame at `86.583 s`.
- Tears of Steel contained the decisive false-positive case: blurred backs of
  heads at `73.750 s` and `82.292 s` were reported at approximately `0.673` and
  `0.598` confidence. A visible face at `65.208 s` scored at approximately
  `0.796` confidence.
- Cosmos detections were credible, but the bounded positive bonus did not
  force a human frame over the stronger base-ranked sheep close-up. This is
  intended preference rather than a face requirement.

## Calibration Decision

Face-composition quality now requires Vision confidence of at least `0.70` and
weights every eligible face by its confidence. The group contribution is also
confidence-weighted. False positives are asymmetric here: because the policy
can only add a bonus, a false positive can actively choose a worse frame while
a missed face merely preserves the base ranking. A conservative threshold is
therefore appropriate.

On Tears of Steel with the animation profile, the old unqualified detections
could promote the blurred back-of-head frame at `82.292 s`. With the calibrated
gate, the same default face policy promotes the visible face at `65.208 s` over
the base winner at `39.542 s`. The repository's normal recommended five-video
quality command retained all five previously recorded winners.

## End-to-End Cost

The paired schema-7 benchmark used the 120-second Tears of Steel fixture,
1280×534 H.264 input, 1280×720 maximum output, 24 planned candidates, 22 decoded
candidates after midroll exclusion, four decoder lanes, three fresh
process-cold workers, and five separately warmed workers on an Apple M1 Pro
running macOS 15.7.4. Only the default eight-candidate face preference changed.

| Configuration | Cold median | Warm median | Cold peak RSS increase | Warm peak RSS increase | Winner |
| --- | ---: | ---: | ---: | ---: | ---: |
| Face preference off | 420.00 ms | 298.97 ms | 112.8 MiB | 45.3 MiB | 39.542 s |
| Face preference on | 570.40 ms | 364.16 ms | 145.3 MiB | 59.1 MiB | 65.208 s |

The measured opt-in adds `150.39 ms` (`35.8%`) to the process-cold median and
`65.19 ms` (`21.8%`) to the process-warm median in this configuration. Warm
face analysis itself took a median `63.24 ms` for all eight inspected frames.
The option remains explicit and bounded; it is not a zero-cost default.

## Remaining Limits

Five videos cannot establish detector recall or a universal `0.70` threshold.
The next calibration set needs deliberately selected, freely redistributable
examples for multiple stylized-face designs, groups, extreme close-ups,
profiles and occlusion, plus scenes with people-shaped objects but no human
face. It also needs multiple independent visual reviewers. Until then, face
preference remains a best-effort, opt-in ranking bonus rather than a guarantee.
