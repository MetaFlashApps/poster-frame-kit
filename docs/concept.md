# PosterFrameKit – Concept

## Summary

PosterFrameKit is a native Swift package that selects one strong individual
frame from a video for use as a poster or thumbnail. It runs locally on Apple
platforms, remains free of external package dependencies in version 1.x, and
can evaluate frames from custom decoders through a public protocol.

The package has no knowledge of any consuming application, media library, or
third-party decoder. Those integrations remain at the application boundary.

## Problem

A frame at a fixed position is quick to generate but often unsuitable:

- black fade, intro, or credits
- motion blur or crossfade
- title card instead of the subject
- burned-in subtitles
- flat, low-contrast, or technically damaged images

Existing tools usually solve a different problem: they extract frames, create
a summary from multiple scenes, or bring large dependencies such as OpenCV and
Python. PosterFrameKit focuses on the narrow task of finding “one good poster
frame.”

## Product Promise

PosterFrameKit aims to:

1. select a reproducible, visually useful frame,
2. make the result explainable through metrics and a score,
3. remain fast enough for an interactive app when processing short local
   videos,
4. support AVFoundation and custom decoders through the same analysis path,
5. treat animation as a first-class profile.

It explicitly does not promise to understand the semantically most important
moment in a film. Without a domain-specific model, the “best frame” remains a
measurable, calibratable heuristic.

## Positioning

### Compared with Apple's Vision Example

Since macOS 15 and iOS 18, Apple has demonstrated high-quality video-frame
selection using `CalculateImageAestheticsScoresRequest`, `VideoProcessor`, and
feature prints. This validates the use case but does not fully replace
PosterFrameKit:

- PosterFrameKit supports systems older than the Vision example APIs.
- A deterministic Accelerate path remains backward-compatible and measurable.
- An animation profile can prioritize differently from general photo
  aesthetics.
- Custom frame sources support MKV and legacy containers without making the
  package depend on FFmpeg.

On newer systems, the demo uses Vision as a benchmark reference and also shows
a transparent 50/50 ranking from normalized Vision and PosterFrameKit scores.
Vision's `-1...1` range is mapped linearly to `0...1` and averaged with the
PosterFrameKit score. `isUtility` is visible but is not used as a hidden
penalty. Because the comparison seeks only one winner, Apple's feature-print
diversification for multiple thumbnails is outside its scope.

The library's base quality scoring remains independent of Vision aesthetics.
An explicit option on macOS 15+, iOS 18+, tvOS 18+, and visionOS 2+ can use
Vision-first aesthetic ranking for at most 24 leading candidates. Older
systems and analysis errors preserve the preceding ranking.

## Public API

The API remains small and system-oriented:

```swift
import PosterFrameKit

let result = try await PosterFrameKit.bestFrame(in: videoURL)

let artwork = try await PosterFrameKit.embeddedArtwork(in: videoURL)

var options = PosterFrameOptions(profile: .animation)
options.searchRange = 0.08...0.90
options.maximumFramesExamined = 40
options.excludedRanges = [0.46...0.54]
options.subtitleAvoidance = PosterFrameSubtitleOptions()
options.facePreference = PosterFrameFaceOptions()
options.aestheticPreference = PosterFrameAestheticOptions()
options.outputSize = CGSize(width: 640, height: 360)

let configured = try await PosterFrameKit.bestFrame(
    in: videoURL,
    options: options
)
```

For already decoded frames,
`PosterFrameKit.evaluate(pixelBuffer:profile:)` returns the score and metrics
without video sampling. Custom decoders connect to the same selection path
through `PosterFrameKit.bestFrame(from:options:)`.

### Validation and Normalization

`PosterFrameOptions` remains mutable after initialization. Before use,
`normalized()` therefore creates a validated, canonical copy:

- finite `searchRange` bounds are clamped to `0...1`,
- `excludedRanges` are intersected with `0...1`, sorted, and merged when they
  overlap, and they must not fully cover the search range,
- `maximumFramesExamined` must be at least `1`,
- `outputSize` must be either `nil` or contain two finite, positive dimensions,
  and
- custom weights must be finite and nonnegative, include at least one positive
  value, and are scaled to sum to `1`.

A search range entirely before or after the video collapses to the nearest
boundary timestamp, `0` or `1`, respectively. Normalizing an already normalized
result does not change it. Invalid values deterministically produce
`PosterFrameError.invalidOptions` before a frame source is accessed. The
selection API enforces this boundary internally; the public method additionally
allows early validation.

The result contains at least:

- `CGImage`
- the frame's actual `CMTime`
- normalized overall score
- public individual metrics

Multiple candidates are a useful extension but are not part of the initial
single-result contract without demonstrated external demand.

### Embedded Artwork

Embedded artwork is an input-level shortcut rather than another selection
policy. `embeddedArtwork(in:)` reads AVFoundation's normalized common artwork
metadata and returns the first image that ImageIO can decode. It performs no
video seeks, candidate analysis, or scoring. Missing, empty, unsupported, and
malformed artwork items are skipped; an asset metadata failure is still an
error, and cancellation is mapped to `PosterFrameError.cancelled`.

The API returns `CGImage?`, not `PosterFrameResult?`, because container artwork
has no actual video timestamp, quality metrics, or ranking evidence. Callers
choose the policy explicitly: use deliberate artwork when present, otherwise
call a normal `bestFrame` API. For custom containers such as Matroska, the
application-owned container adapter reads attachments before entering
PosterFrameKit's decoder-independent frame-source path.

## Profiles

- `general`: balanced default weighting
- `animation`: gives more weight to clear lines and handles flat color areas
  and cel-style composition cautiously
- `custom`: public weights for controlled special cases

Profiles initially adjust weights and soft thresholds. As few properties as
possible are rejected outright so valid black-and-white, night, or sepia scenes
are not categorically lost.

## Architecture

```text
Sources/PosterFrameKit/
├── PosterFrameKit.swift
├── PosterFrameKit+EmbeddedArtwork.swift
├── Options.swift
├── PosterFrameProfile.swift
├── PosterFrameWeights.swift
├── FrameMetrics.swift
├── PosterFrameResult.swift
├── PosterFrameSample.swift
├── PosterFrameSubtitleOptions.swift
├── PosterFrameFaceOptions.swift
├── PosterFrameAestheticOptions.swift
├── PosterFrameError.swift
├── PosterFrameCancellation.swift
├── FrameSource.swift
├── Metadata/
│   └── AVFoundationEmbeddedArtworkLoader.swift
├── PosterFrameKit.docc/
├── Sampling/
│   └── CandidatePlanner.swift
├── Sources/
│   ├── AVFoundationFrameSource.swift
│   └── PixelBufferImageConverter.swift
├── Analysis/
│   ├── AnalysisBuffer.swift
│   └── FrameAnalyzer.swift
├── Performance/
│   └── PosterFramePerformanceRecorder.swift
├── Scoring/
│   ├── ProfileWeights.swift
│   └── FrameScorer.swift
├── Selection/
│   ├── CandidateAccumulator.swift
│   ├── CandidateAnalysisDependencies.swift
│   ├── CandidatePool.swift
│   ├── CandidateRefinementPipeline.swift
│   ├── EvaluatedCandidate.swift
│   ├── PosterFrameResultFactory.swift
│   └── RefinedCandidate.swift
├── Face/
│   ├── FaceAnalyzing.swift
│   ├── FaceCandidateReranker.swift
│   └── VisionFaceAnalyzer.swift
├── Aesthetics/
│   ├── AestheticAnalyzing.swift
│   ├── AestheticCandidateReranker.swift
│   └── VisionAestheticAnalyzer.swift
├── Subtitle/
│   ├── SubtitleAnalyzing.swift
│   ├── SubtitleBandHeuristic.swift
│   ├── SubtitleCandidateReranker.swift
│   └── VisionSubtitleAnalyzer.swift
├── Vision/
│   └── VisionRequestCancellation.swift
```

Application-owned container adapters implement `PosterFrameSource` and keep
their decoder types and dependencies outside PosterFrameKit. The public custom
source remains serialized until a reproducible external use case demonstrates
that a bounded concurrent contract can improve runtime without compromising
memory, cancellation, actual timestamps, or deterministic ranking.

`CandidateAccumulator` is deliberately the small stateful boundary shared by
all decoder paths. `CandidatePool` owns actual-time deduplication, deterministic
top-candidate retention, and decoder-error ordering. The stateless
`CandidateRefinementPipeline` composes optional face, subtitle, and aesthetic
policies with isolated rollback, while public result construction remains a
separate service. This keeps optional Apple adapters out of the core ranking
domain without introducing a generic service layer or a dependency-injection
framework.

## Frame Source and Sampling

The default path uses AVFoundation and distributes a bounded number of
candidates evenly over the configured search range, including both range
boundaries. It then removes timestamps inside normalized exclusion ranges. The
number actually requested can therefore be lower than the configured maximum.
A single candidate normally falls at the range midpoint. If that point is
excluded, it uses the midpoint of the widest remaining interval, choosing the
earlier interval in a tie.

The current `AVAssetImageGenerator` path uses exact time tolerances. Larger
tolerances remain a later optimization requiring benchmarks and are not
interpreted as a guarantee that only codec keyframes will be returned.

Every source therefore returns both the requested and actual time. Sampling
deduplicates identical actual frames and prevents a decoder with coarse seek
points from evaluating the same candidate repeatedly.

### Bounded Parallel Decoding

URL-based AVFoundation selection distributes contiguous groups of sorted
candidate timestamps over persistent `AVAssetImageGenerator` instances. The
pool is bounded to four lanes on macOS. iOS, tvOS, and visionOS remain
serialized until reproducible device-specific measurements justify a change.
The macOS limit is also capped by the number of candidates and available
processor capacity.

Decoded samples enter one shared accumulator. Analysis, actual-time
deduplication, scoring, and tie resolution therefore remain common with the
serialized custom-source path. Completion order cannot
change the winner because score and actual time form a deterministic ordering.
`PosterFrameSource` keeps its small single-frame contract and exposes no batch
API.

On the generated 30-second 1280×720 H.264 fixture, the Apple M1 Pro/macOS
15.7.4 report measured a warm median of `575.95 ms` before the change and
`233.63 ms` with four lanes. The selected time and score were identical. The
historical report's process-lifetime peak RSS is not interpreted as
selection-scoped memory. A non-public
23-minute H.264 validation clip showed the same winner and a warm reduction
from approximately `1.12 s` to `0.45 s`; this second result is directional only
because the source cannot be redistributed.

The default mode examines all planned unique actual frames. When scores are
identical, the earlier actual timestamp deterministically wins. Early
termination may later be introduced as an explicit `fast` mode, not as silent
default behavior.

## Analysis

The first version uses a reusable luma buffer with at most `160` pixels on its
long edge and a small number of robust metrics:

| Metric | Purpose |
|---|---|
| Mean brightness | Detect black and white fades |
| Luma variance | Detect flat, low-information images |
| Entropy | Estimate information content |
| Sharpness | Penalize blur and many crossfades |
| Colorfulness | Soft profile signal, not a blanket filter |
| Visual noise | Detect dense, incoherent high-frequency patterns |

The analysis directly reads BGRA, ARGB, RGBA, 8-bit monochrome, and bi-planar
4:2:0 luma/chroma buffers. Unsupported formats return a defined error. The
AVFoundation path converts the transformed, display-ready `CGImage` to BGRA
once; after that, AVFoundation and custom sources use exactly the same analysis
and scoring logic. Reusable buffers avoid per-candidate allocations. Final
result images share one immutable, thread-safe `CIContext` rather than
recreating its render state for each conversion.

Version 0.1 measures sharpness with normalized Tenengrad edge energy. Compared
with Laplacian variance, it responds directly to strong directional edges and
therefore fits the initial animation weighting. Synthetic edge and flat-field
tests support the choice; no quality advantage over Laplacian will be claimed
before the shared fixture benchmark.

A separate visual-noise estimate measures four-neighbor Laplacian residual
energy and maps only the dense high-frequency end of that signal to `0...1`.
The scorer applies a soft penalty capped at 25%. This prevents static-like
patterns from exploiting both entropy and sharpness while leaving ordinary
animation edges below the penalty range. Synthetic fixtures define the metric;
the local clip that exposed the failure is not redistributable benchmark data.

Raw histogram entropy remains a public deterministic metric, but its scoring
contribution is structure-qualified. A smooth transition caps the trusted
entropy only while coherent Tenengrad strength is below the range produced by
ordinary edges; dense visual noise cannot supply that confidence. This keeps
the analyzer explainable while preventing an evenly distributed grayscale
gradient from outranking clearer structured content merely through histogram
coverage.

### Image Region

A fixed central crop is not a universal default. It often removes letterbox
bars but can also lose subjects deliberately placed near an edge. The order of
work is therefore:

1. use the full frame as the correct baseline,
2. evaluate simple, robust bar detection,
3. offer a central analysis region only as a profile or option decision.

The first 70%-height experiment reduced the analyzed pixels by 30% and direct
analysis time by 26–27%, but that stage represented only a few milliseconds of
the complete selection. Two reversed 15-run ARM64 batches showed no repeatable
end-to-end improvement, and the generated fixture selected a different frame.
The experimental implementation was removed rather than becoming public or
profile behavior.

### Optional Candidate Refinements

Subtitle avoidance, face preference, and aesthetic preference are modeled as
separate optional domain policies rather than additional base image metrics:

- `PosterFrameSubtitleOptions` is the public value object that enables the
  policy and bounds its candidate count and maximum penalty;
- `PosterFrameFaceOptions` independently bounds face inspections and the
  maximum composition bonus;
- `PosterFrameAestheticOptions` bounds Vision aesthetics inspections and the
  maximum absolute score adjustment;
- the base scorer owns only deterministic image-quality metrics;
- internal analyzer ports isolate recognition and OS-model inference from
  ranking;
- Vision adapters implement those ports with Apple frameworks; and
- the re-ranker composes base candidates, recognition evidence, and the policy
  without duplicating decoding or scoring.

This boundary keeps the default selection path unchanged. When subtitle, face,
and aesthetic options are `nil`, PosterFrameKit constructs no recognizer,
retains no leading candidate group, and performs no Vision refinement.
Saliency remains a possible future refinement behind the same boundary, not an
additional responsibility of the base scorer.

The implemented subtitle flow is:

```text
existing ranking → bounded leading group → lower-third recognition
→ internal geometry-weighted capped penalty → deterministic final ranking
```

The implemented face flow is:

```text
existing ranking → bounded leading group → Vision face rectangles
→ deterministic size/placement/group score → capped bonus → final ranking
```

The implemented aesthetics flow is:

```text
existing refined ranking → bounded leading group → Vision aesthetics score
→ align aesthetic base while preserving content adjustments → final ranking
```

Vision image aesthetics pins revision 1 and consumes the same display-oriented
pixel buffers as the base analyzer. Its `-1...1` score is normalized to
`0...1`; the default maximum adjustment of `1` allows it to replace the
deterministic aesthetic base while retaining separate face and subtitle
effects. `isUtility` remains evidence and is not penalized twice. The default
checks at most 24 candidates. Unsupported OS versions and analysis failures
leave the preceding ranking unchanged; cancellation is propagated.

The face scorer ignores detections covering at most 1% of the image and
extreme close-ups covering at least 65%. It rewards a useful intermediate size,
central composition, and a small capped group signal. A frame without a face
receives neither a bonus nor a penalty. The default option checks at most eight
candidates and caps the bonus at `0.04`. Analysis stops when the remaining
candidate cannot overtake the current winner even with that full bonus.

Face detection pins Vision face-rectangle revision 3, consumes existing
display-oriented pixel buffers, and never causes another video seek. Failure
discards the face stage without disturbing the base ranking, while cancellation
is propagated. Strongly stylized faces remain a documented limitation until
the reproducible quality set includes animation fixtures.

The adapter first runs `VNRecognizeTextRequest` in fast mode over the bottom
third. A cheap luma edge-band heuristic does not classify a frame itself; it
only requests an accurate retry when fast recognition found nothing but the
region remains suspicious. This hybrid addresses observed fast-mode misses
without paying accurate-mode cost for every inspected candidate. Recognized
regions are filtered and weighted by coverage, count, centrality, and lower
placement. General text outside the lower third is intentionally ignored, so
most signs remain valid. Credits or signs within the lower third can still be
treated as subtitle-like; this is a documented limitation rather than a hidden
content classifier.

The default refinement retains at most eight candidates and caps the penalty
at `0.08`. Because the adjustment can only lower a score, recognition stops
once the next base score cannot beat the best adjusted candidate. If any
recognition call fails, the complete optional stage is discarded instead of
treating that candidate as text-free. Cancellation is always propagated. The
base metrics and `PosterFrameResult.score` remain unchanged;
`subtitlePenalty` and `adjustedScore` expose the refinement separately.

The former, ineffective `PosterFrameWeights.subtitlePenalty` placeholder was
removed. Subtitle avoidance is not a relative contribution to the base metric
sum and therefore belongs only in `PosterFrameSubtitleOptions`.

The generated subtitle fixture locks the intended dialogue/credit/sign
boundary. A separate checksum-locked live-action calibration renders official
English and German subtitle cues over matched Tears of Steel controls. Its
first 52-sample run motivated a narrow bright-stroke retry signal that recovered
four small outline misses without false positives in the reviewed set. This is
still one film and two Latin-script languages, so the option remains disabled
by default until broader native burned-in material covers animation, more
typography and languages, lower-third signs, credits, and text-free scenes.

When multiple refinements are enabled, face bonuses are applied before
subtitle penalties, followed by aesthetic adjustments. Each Vision stage rolls
back independently if it fails.

## Performance

Performance targets are defined per fixture class, not as a universal promise.
Measurements include at least:

- time to first result
- direct end-to-end, decode/seek, conversion, and analysis timings
- number of unique actual frames decoded
- peak memory per selection
- cold and warm cache states

Stage timings are instrumented at their actual boundaries. A residual such as
“end-to-end minus separately measured analysis” is not labeled decode time.
Likewise, a process maximum after fixture generation is not treated as the
memory cost of one selection.

`PosterFrameKitBenchmark` generates its fixture before launching isolated
measurement workers. It reports independent process-cold and process-warm run
groups and samples current resident memory every 2 ms only around the measured
selection. Starting, peak, ending, and peak-increase values are retained for
each run. The filesystem cache remains explicitly uncontrolled. Stage durations
are cumulative work; parallel stages overlap and are never summed to
manufacture an end-to-end result.

A provisional target for a local H.264 video of approximately 30 seconds is a
result below 500 ms on a current Apple Silicon Mac. Long videos, legacy codecs,
and custom decoders receive separate budgets. Only measured figures appear in
the public README.

## Cache

PosterFrameKit provides no persistent thumbnail or metric cache. The caller
owns media identity, file invalidation, storage limits, eviction, and the
relationship between cached images and its library. PosterFrameKit may reuse
short-lived implementation resources such as immutable rendering contexts, but
it does not persist results between selections.

## Non-Goals for Version 1.x

- no video summaries or scene timelines
- no automatic cropping of the final image
- no dedicated container decoder
- no required cloud service or telemetry
- no required ML or Core ML model
- no UI components

## Open Source

PosterFrameKit is intended for release under the MIT license after validation
against its public quality and platform criteria. The community version needs:

- reproducible tests using generated or freely licensed videos; the initial
  checksum-locked download catalog and silent normalization recipes live under
  `Benchmarks/Fixtures`
- traceable benchmark and fixture-fetch scripts
- a results gallery with source and license information
- DocC for the public API
- Semantic Versioning and a changelog

The blog post and public promotion will follow only when the gallery shows that
the package finds better poster frames more often than fixed timestamps.
