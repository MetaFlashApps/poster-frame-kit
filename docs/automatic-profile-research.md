# Automatic Profile Resolution – Research Plan

## Status

This document describes a deferred, pre-1.0 research project. It does not
define current public behavior and does not commit PosterFrameKit to shipping
an automatic profile or a bundled classifier.

The first experiment targets a conservative choice between `general` and
`animation`. Explicit caller-selected profiles always remain authoritative.

## Objective

An automatic mode should answer the product-specific question:

> Which PosterFrameKit scoring profile is more likely to produce the stronger
> poster frame for this video's visual style?

It should not attempt to provide an authoritative genre label. A
photorealistic 3D production may correctly resolve to `general`, while a
strongly stylized live-action production may benefit from `animation`. The
quality of the selected poster frame is the target, not taxonomic purity.

## Initial Scope

The first research model has two routing outcomes:

| Routing outcome | Meaning |
| --- | --- |
| `generalScoring` | Use the balanced `general` profile. This is also the safe fallback. |
| `animationScoring` | Use the line-, contrast-, and flat-color-oriented `animation` profile. |

Low confidence, disagreement between probe frames, model failure, unsupported
platforms, and genuinely ambiguous training examples all resolve to
`generalScoring`.

The first model does not select `custom`. Earlier `liveAction` and `screencast`
preset experiments were removed before the public beta because their fixture
coverage did not justify distinct public behavior. Rendering style remains an
evaluation tag rather than an automatic routing target.

## Labels and Subcategories

### Keep routing labels small

`anime`, `comic`, `3D animation`, `retro film`, and similar concepts must not
be initial model outputs. Making every visual category an output class would
fragment the dataset and still require a second mapping from genre to scoring
profile.

Instead, each source video receives:

1. one reviewed routing label used for training;
2. orthogonal taxonomy tags used for dataset balance and sliced evaluation;
3. a production identifier used to prevent train/test leakage; and
4. provenance and license information.

A taxonomy tag may become a routing target only after measurements show that
it consistently needs distinct scoring behavior and enough independent source
material exists to train and test it.

### Controlled taxonomy

The manifest should use controlled values from independent dimensions rather
than one deep hierarchy.

#### Rendering domain

- `two-dimensional-animation`
- `three-dimensional-animation`
- `stop-motion`
- `live-action`
- `mixed-media`
- `screen-content`

#### Visual style

- `anime`
- `western-cartoon`
- `comic`
- `painterly`
- `rotoscoped`
- `stylized-3d`
- `photorealistic-3d`
- `photographic`
- `none`

#### Capture and source character

- `modern-digital`
- `film-scan`
- `retro-telecine`
- `analog-video`
- `restored-archive`
- `synthetic`

#### Evaluation conditions

- `bright`
- `dark`
- `grainy`
- `low-resolution`
- `monochrome`
- `high-motion`
- `crossfades`
- `faces`
- `groups`
- `no-faces`
- `subtitles`
- `credits`
- `title-cards`

These tags are not inferred at runtime. They expose dataset gaps and allow the
evaluation report to answer questions such as “Does automatic resolution work
for 2D anime but fail for photorealistic 3D?” or “Are retro film scans being
routed to `animation` because of strong grain and edges?”

The [visual taxonomy examples](assets/automatic-profile-examples/README.md)
show the intended distinction between every controlled value. They are
AI-generated explanatory images only and must not be used for training,
testing, or benchmark evidence.

## Dataset Manifest

The automatic-profile dataset should extend the repository's existing
fixture-manifest principles without duplicating downloadable-source metadata.
A conceptual entry is:

```json
{
  "id": "example-source",
  "productionID": "example-production",
  "split": "training",
  "routingLabel": "animationScoring",
  "renderingDomain": "two-dimensional-animation",
  "visualStyles": ["anime"],
  "sourceCharacter": ["modern-digital"],
  "conditions": ["faces", "subtitles", "dark"],
  "reviewStatus": "reviewed",
  "license": {
    "spdx": "CC-BY-4.0",
    "url": "<license-url>"
  }
}
```

The real schema should reference the shared quality-fixture source entry where
possible. It must not use placeholder URLs, undocumented local paths, or
copyrighted anime clips in checked-in data.

All clips from one film, episode, franchise segment, or other recognizable
production belong to the same split. Randomly splitting frames from the same
video between training and testing would measure memorization of characters,
backgrounds, and color palettes rather than transfer to unseen productions.

## Creating Routing Labels

Labels should come from PosterFrameKit results rather than genre names:

1. Run `general` and `animation` over an identical candidate plan and options.
2. Review the winners and a bounded leading group from both rankings.
3. Repeat at the candidate budgets used by the quality matrix when practical.
4. Label the source only when one profile is consistently preferable.
5. Keep ties and disputed sources as an evaluation-only `uncertain` group.

An initial local review may use one reviewer. Any release-quality dataset
should record multiple independent reviews or an explicit adjudication step.
The review artifact must preserve timestamps and score evidence without
committing copyrighted frames.

## Frame Extraction

A reproducible script should derive classifier inputs from each licensed
source:

- use the same normalized search range and exclusions as selection;
- select fixed probe positions so repeated generation is stable;
- avoid opening, ending, and configured midroll regions;
- remove duplicate actual timestamps and near-identical frames;
- preserve source aspect ratio with a neutral fit policy;
- record the source checksum and exact extraction recipe; and
- keep generated training images outside the Git repository.

The first comparison should evaluate three and five probe frames per video.
Five offers stronger consensus; three may have a better latency profile. The
decision must follow video-level accuracy and runtime measurements rather than
assumption.

## Model Candidates

### Recommended baseline: Create ML transfer learning

Train a binary `MLImageClassifier` using Apple's system image feature print as
the feature extractor. This keeps inference within Vision/Core ML, requires no
external Swift package, and can consume the `CVPixelBuffer` values already
decoded by PosterFrameKit.

The research matrix should compare:

- Image Feature Print V1 for the package's older supported systems;
- Image Feature Print V2 for newer-system accuracy, model size, and latency;
- a small classifier built only from deterministic handcrafted measurements;
  and
- the built-in Vision `illustrations` confidence as a deliberately weak
  control.

The built-in Vision classifier must not ship as the sole resolver. Initial
local evidence found high `illustrations` confidence on one clear anime image
but very low confidence on the repository's Morevna, Big Buck Bunny, Sintel,
and Cosmos Laundromat fixtures.

Large zero-shot vision-language models and general-purpose external inference
runtimes are outside the version-1.x product boundary. Model quantization or
palettization is considered only after the uncompressed candidate passes the
quality baseline.

## Runtime Design

An experimental public shape could eventually be:

```swift
let options = PosterFrameOptions(profile: .automatic)
let result = try await PosterFrameKit.bestFrame(in: videoURL, options: options)
```

The result must expose the resolved behavior rather than hiding it:

```swift
result.resolvedProfile
result.profileResolutionConfidence
```

Names and exact types remain an API-review decision.

The selection pipeline should operate in two bounded stages:

1. Decode a fixed subset of three or five probe candidates in parallel.
2. Analyze their ordinary frame metrics and run the profile classifier.
3. Aggregate the per-frame evidence with a precision-first consensus policy.
4. Resolve to `animation` only with strong agreement; otherwise use `general`.
5. Reuse the probe candidates in the ordinary candidate pool.
6. Decode and rank the remaining planned candidates with the resolved profile.
7. Run the existing subtitle, face, and aesthetics stages without duplicating
   their logic.

This structure performs no extra probe seek. It may introduce a synchronization
gate before the remaining candidate lanes start, so wall time must be measured.
The model instance should be shared behind an actor, and model load or
inference failure must fall back to `general` without logging through `print`.

For mixed-content videos, a provisional policy is to require a strong majority
of probe frames and a calibrated aggregate confidence before selecting
`animation`. Exact thresholds must be derived from the held-out video set.

When Vision-first aesthetics evaluates the complete candidate set, the base
profile has much less influence on the final result. Automatic resolution is
therefore primarily valuable for the deterministic path, older systems,
custom decoders, and latency-first configurations.

## Evaluation and Acceptance Gates

Frame-level classifier accuracy is insufficient. The experiment must report:

- confusion matrices and precision/recall per frame;
- routing accuracy per complete held-out video;
- results sliced by every controlled taxonomy dimension;
- confidence calibration and the percentage falling back to `general`;
- selected timestamps and human-reviewed poster quality for automatic,
  explicit `general`, and explicit `animation`;
- three-versus-five-probe quality and latency;
- process-cold model load and first inference;
- process-warm inference and complete end-to-end selection time;
- peak resident memory and model artifact size;
- cancellation latency and concurrent-selection behavior; and
- failure behavior on unsupported platforms and custom frame sources.

Before implementation begins, the experiment must define a precision target
for automatically choosing `animation`. Recall may be lower because a cautious
fallback to `general` is preferable to a confident wrong override.

The model is accepted only if it improves reviewed selection quality over
always using `general`, does not merely reproduce filename or production
identity, and has a justified runtime, memory, package-size, provenance, and
license cost. A model that classifies genres accurately but does not improve
poster selection is rejected.

## Work Plan

### Stage A – Dataset and review tooling

- Extend the fixture catalog with routing labels, controlled tags, production
  groups, and split ownership.
- Add deterministic frame extraction outside the repository.
- Add a side-by-side profile-review report that records decisions without
  copyrighted images.
- Expand independent licensed productions before training.

### Stage B – Offline model comparison

- Train Create ML Feature Print V1 and V2 baselines.
- Compare three and five frames, per-frame voting, median confidence, and a
  calibrated consensus rule.
- Record video-level and taxonomy-sliced results on unseen productions.
- Measure model artifacts and native Apple Silicon inference.

### Stage C – Internal runtime prototype

- Add an internal resolver port and injected test double without changing the
  public profile enum.
- Reuse probe frames in the normal candidate plan.
- Verify deterministic fallback, cancellation, decoder errors, and optional
  refinement composition.
- Run the complete quality and performance suites in reversed order.

### Stage D – Public API decision

- Add `.automatic` only after the model and runtime gates pass.
- Document availability, fallback, confidence semantics, and model provenance.
- Expose the resolved profile in results and diagnostics.
- Keep explicit profiles as stable caller overrides.

## Approaches Rejected for the Initial Experiment

- filename, extension, codec, resolution, or container heuristics;
- trusting optional embedded genre metadata as the sole signal;
- classifying one frame;
- treating Vision's `illustrations` label as an animation detector;
- emitting many genre classes before the binary routing problem is solved;
- random frame-level train/test splits from the same production;
- training on copyrighted private clips for a public model; and
- silently changing an explicitly selected profile.

## Open Questions

- Does Feature Print V1 classify stylized 2D material well enough, or would an
  automatic mode require a newer deployment floor and Feature Print V2?
- Should ambiguous but consistently photorealistic 3D material be labeled
  `generalScoring`, and how should that decision be explained in documentation?
- Can three probe frames match five on mixed and short content?
- Does profile resolution still improve quality when face and subtitle
  refinements are active but aesthetics is disabled?
- Is a separate `screencastScoring` target justified after the binary resolver
  is stable?
- Can the model and its full training provenance satisfy the public-release
  legal and package-size gates?
