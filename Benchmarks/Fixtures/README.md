# Quality Fixtures

`manifest.json` is the versioned source of truth for downloaded and generated
quality fixtures. Downloaded entries record the upstream URL, source byte count
and SHA-256, license, attribution, and deterministic normalization settings.
Generated entries pin the Swift generator, variant, version, dimensions, frame
rate, duration, and keyframe interval. Every entry records semantic tags, its
intended PosterFrameKit profile, review state, and acceptable result ranges.

Neither upstream media nor normalized clips are committed. Both live below
`Benchmarks/.fixtures`, which is ignored by Git and excluded from the Swift
package downloaded by consumers.

The separate `subtitle-calibration.json` manifest reuses the checksum-locked
Tears of Steel source and adds official English and German SRT inputs. Fetch or
verify that paired real-material set with:

```bash
Scripts/fetch-subtitle-calibration-fixtures.py
Scripts/fetch-subtitle-calibration-fixtures.py --verify-only
```

The subtitle benchmark renders controlled outline and boxed variants in memory
over exact decoded source frames. It does not commit or modify the upstream
video. See [Subtitle-Avoidance Calibration](../../docs/subtitle-calibration.md)
for labels, reproduction commands, measured results, and limitations.

## Requirements

- Python 3
- FFmpeg with `ffmpeg` and `ffprobe` on `PATH` for downloaded fixtures
- approximately 3.2 GiB for the downloaded core source cache and normalized
  clips

On macOS with Homebrew, FFmpeg can be installed with:

```bash
brew install ffmpeg
```

## Fetch the Core Set

From the repository root:

```bash
Scripts/fetch-benchmark-fixtures.py
```

The default command downloads five active sources, validates their byte counts
and SHA-256 hashes, extracts archives when necessary, removes every audio
stream, and creates 120-second H.264/yuv420p clips inside a 1280×720 maximum
pixel bounding box. Existing verified downloads are reused. Generated entries
are validated and skipped by the Python fetcher; the Swift quality harness
creates and reuses them on demand from the same catalog.

Useful maintenance commands:

```bash
# Inspect the complete catalog without downloading anything.
Scripts/fetch-benchmark-fixtures.py --list --tier all

# Validate only the checked-in manifest schema.
Scripts/fetch-benchmark-fixtures.py --check

# Verify the local core cache and every normalized clip.
Scripts/fetch-benchmark-fixtures.py --verify-only

# Fetch one source and normalized clip.
Scripts/fetch-benchmark-fixtures.py --fixture sintel

# Cache sources without running FFmpeg.
Scripts/fetch-benchmark-fixtures.py --download-only

# Recreate normalized clips after a reviewed transform change.
Scripts/fetch-benchmark-fixtures.py --force
```

After verification, run the shared quality comparison with:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24
```

It writes a JSON report and PosterFrameKit, pure-Vision, and 50/50-hybrid
winner images plus an independently decoded fixed-midpoint baseline below
ignored `Benchmarks/.quality-results`.

Maintainers can reproduce the checked-in 80%-quality JPEG pairs at the same
time with:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --candidates 24 \
  --gallery-directory docs/assets/results-gallery \
  --report Benchmarks/Reports/m1-pro-macos-15.7.4-quality.json
```

The publication directory retains its own attribution README. The benchmark
does not delete stale files, so the default five-fixture run is required when
refreshing the complete gallery.

The default run preserves the reviewed five-fixture baseline. Generated
fixtures remain excluded until their acceptable ranges receive human review.
Run one explicitly, or include the complete pending catalog, with:

```bash
arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --fixture generated-coarse-timestamps \
  --candidates 24

arch -arm64 swift run -c release PosterFrameKitQualityBenchmark \
  --include-pending-review \
  --candidates 24
```

`--allow-unverified-source` exists only for maintainers establishing a new
source lock. Active checked-in fixtures must have a SHA-256 before review.

## Downloaded Core Coverage

| Fixture | Coverage | Source download |
| --- | --- | ---: |
| Morevna Demo | 2D open anime, faces, dark scenes, opening credits | 31.9 MiB |
| Big Buck Bunny | bright and colorful 3D animation, motion | 397.4 MiB |
| Sintel | stylized faces, action, crossfades, darker animation | 649.7 MiB |
| Tears of Steel | live action, faces, groups, VFX, motion | 354.9 MiB |
| Cosmos Laundromat | detailed 3D animation and complex composition | 468.5 MiB |

The manifest also catalogs `Meridian` and `Sol Levante` as deferred extended
fixtures. They are intentionally skipped: Meridian needs an explicit HDR
preservation or deterministic SDR tone-mapping policy, while the smallest
complete Sol Levante SDR master is approximately 16 GB.

## Generated Core Coverage

| Fixture | Shape | Purpose |
| --- | --- | --- |
| Patterns | 1280×720, 12 fps, 30 s | dark scenes, gradients, color bars, checkerboards, and structured patterns |
| Subtitle calibration | 1280×720, 12 fps, 30 s | dialogue subtitles and credits in the lower third, a clean control, and an eligible central scene sign |
| Very short, single scene | 640×360, 12 fps, 1 s | duration clamping and dense candidate requests |
| Very short, multiple scenes | 640×360, 12 fps, 3 s | a dark opening followed by distinct short scenes |
| Coarse timestamps | 640×360, 2 fps, 8 s | long-GOP seeking, coarse actual times, and actual-time deduplication |

The generator implementation is shared by both benchmark executables and its
integration tests. Manifest tests fail when catalog metadata drifts from the
Swift definition, so changing a generated fixture requires an explicit version
or identifier update.

## Review Semantics

`acceptableTimeRanges` are relative to each normalized or generated clip, not
the upstream movie. Reviewed ranges represent frames that would make reasonable
poster candidates. Multiple ranges are intentional: quality checks must not
require one exact timestamp when several shots are equally useful.

New fixtures use `pending-human-review` with no acceptable ranges. Their report
field is `null`, not a failed check, until review establishes meaningful bounds.

The ranges are calibration inputs, not permanent claims. Changes require a
visual review and a changelog entry once reports depend on them. A result
outside every range is evidence to inspect; it does not by itself prove a
scoring regression until the selected frame and nearby candidates are reviewed.

## Licensing and Attribution

- **Morevna Project Demo** — visual work licensed CC BY 3.0 by Morevna Project.
  The upstream music has separate CC BY-NC-SA terms, so normalized fixtures are
  always silent.
- **Big Buck Bunny**, **Sintel**, and **Tears of Steel** — Blender Foundation
  Open Movies licensed CC BY 3.0. Preserve the exact attribution recorded in
  the manifest when publishing derived frames or clips.
- **Cosmos Laundromat**, **Meridian**, and **Sol Levante** — assets obtained
  through Netflix Open Content under CC BY 4.0. Exact creator attribution is
  recorded per fixture in the manifest.

Published galleries and reports must retain the fixture id and link back to
this manifest so the source, license, and normalization recipe remain
traceable.
