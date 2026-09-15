# Contributing to PosterFrameKit

Thank you for helping improve PosterFrameKit. The project is still pre-1.0, so
focused bug reports, reproducible quality cases, platform verification, and API
feedback are especially useful.

## Initial Release Feature Freeze

The `0.1.0` release candidate is feature-frozen. Until the first public tag,
pull requests should be limited to reproducible release-blocking bug fixes,
tests, documentation, fixture evidence, and release engineering. New public
APIs, options, profiles, metrics, models, ranking policies, and default changes
are deferred until after `0.1.0` unless the freeze is explicitly lifted.

## Before Opening a Pull Request

- Open an issue before making a public API change, adding a metric, or changing
  sampling and ranking behavior.
- Keep PosterFrameKit focused on selecting poster-frame candidates. Video
  summaries, editing, application-specific adapters, and container decoders
  belong outside the library.
- Do not add external package dependencies to version 1.x. Apple system
  frameworks are allowed when availability and fallback behavior are explicit.
- Do not submit copyrighted video clips, private media, credentials, absolute
  local paths, or generated benchmark outputs containing personal data.

## Development Setup

PosterFrameKit requires Swift 6.2 and a current Xcode installation containing
the SDKs for the platforms being changed.

```bash
swift build
swift test
swift build -c release
swift test --package-path Examples/PosterFrameDemo
swift build -c release --package-path Examples/PosterFrameDemo
Scripts/check-release-hygiene.sh
python3 Scripts/fetch-benchmark-fixtures.py --check
python3 -m unittest discover -s Scripts/Tests -p 'test_*.py'
```

Pull requests must pass the two checks documented in
[Continuous Integration](docs/continuous-integration.md). Performance and
quality harnesses remain evidence-driven release checks rather than unstable
hosted-runner timing gates.

Build the documentation when public API or DocC changes:

```bash
xcodebuild docbuild \
  -scheme PosterFrameKit \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Tests and Evidence

- Add an isolated unit test for every metric and scoring boundary.
- Add deterministic planning and ranking tests for behavioral changes.
- Exercise decoder changes with a generated video integration test.
- Use generated or freely redistributable fixtures. Record source, checksum,
  license, attribution, and normalization steps in the fixture manifest.
- Do not claim a performance improvement without reproducible before-and-after
  reports that include hardware, OS, codec, resolution, candidate count, and
  cache state.

## Documentation and Changelog

Public behavior changes must update the relevant DocC page, `README.md`, and
`CHANGELOG.md`. Roadmap files describe planned work; measured outcomes and
rejected experiments belong in the changelog or research findings.

## Pull Request Checklist

- The change is focused and contains no unrelated formatting rewrite.
- The complete relevant test suite passes under Swift 6.2.
- New public symbols have DocC comments and valid `Sendable` behavior.
- Optional Apple APIs have explicit availability and fallback behavior.
- New third-party material has a verified license and an updated notice.
- No generated media, local paths, credentials, or build artifacts are added.

By contributing, you agree that your contribution is licensed under the
repository's [MIT License](LICENSE).
