# Release Validation

This log records release-relevant checks that cannot be established by the
repository tree alone. It complements CI configuration and reproducible
benchmark reports; it does not replace either.

## 2026-09-15 – Pre-Public CI

The owner confirmed the successful freeze workflow for commit `b70f9b2`:
[GitHub Actions run](https://github.com/MetaFlashApps/poster-frame-kit/actions/runs/34901994965).
This supplies pre-cleanup package, Demo, iOS consumer, Apple platform compile,
and DocC evidence. It is not a CI result for the new clean-history commit.

The subsequent release preparation changes only documentation, licensing,
and the static DocC build/deployment workflow. Before tagging, rerun both CI
jobs on the exact clean-history commit. GitHub Pages publication remains
pending until the deployment workflow succeeds.

Local release validation passed: `166` package tests, `39` Demo tests, `17`
Python tests, package/Demo release builds, release hygiene, and `actionlint`
for both workflows. The static DocC build passed with both project and root
hosting paths; the article, JSON data, and JavaScript returned HTTP 200 in the
local preview. No selection code or defaults changed.

## 2026-09-14 – `0.1.0` Feature Freeze

### Local Package and Examples

- Functional baseline: commit `6e6981e`
- Native ARM64 package result: all `166` tests passed
- Thread Sanitizer result: all `166` tests passed without diagnostics
- PosterFrameDemo result: all `39` tests passed
- Python fixture/fetcher result: all `17` tests passed
- Package and Demo release builds passed
- Release-hygiene validation passed
- Generic macOS and iOS package builds passed without signing
- The macOS DocC archive built successfully

The working-tree changes after the functional baseline only establish and
document the release freeze. Current-commit GitHub Actions evidence remains
open until those documentation changes are committed and pushed.

### Open Release Gates

- Local tvOS and visionOS SDKs are not installed; current-commit CI must supply
  both build results.
- GitHub status and protection settings could not be queried from this clone:
  GitHub CLI is unavailable and the HTTPS remote has no non-interactive
  credentials.
- Repository visibility, branch protection, security settings, release tag,
  release notes, and DocC publication still required release preparation.

## 2026-09-06 – Commit `b2f113e`

### GitHub Actions

- Repository owner confirmed that both required workflow jobs completed
  successfully on GitHub:
  - `Package and Demo`
  - `Apple Platforms and DocC`
- Default-branch protection requiring both checks still needs to be verified in
  the GitHub repository settings before public release.
- Local inspection on 2026-09-06 found `main` aligned with `origin/main` and
  `origin/HEAD` targeting `origin/main`; no other remote-tracking branch was
  present. The local archive branch was not pushed.

### Physical iOS Device

- Device: iPhone 11 Pro
- OS: iOS 26.6.1
- Example: `PosterFrameIOSExample`
- Result: successful video selection from Photos and successful poster-frame
  generation through the package's public URL API.
- Signing used the developer's ignored local signing configuration; no team
  identifier is stored in the repository.

This check establishes one real-device consumer path. It does not establish
performance, memory, thermal behavior, or compatibility across other iPhone
models and iOS releases.

### Thread Sanitizer

- Command: `arch -arm64 swift test --sanitize=thread`
- Result: all 145 package, benchmark, and quality-harness tests passed with no
  Thread Sanitizer diagnostics.
- Coverage included bounded AVFoundation decoding, candidate collection,
  cancellation, and subtitle, face, and aesthetics refinement paths.

The run used the local Apple M1 Pro/macOS 15.7.4 environment. It does not cover
physical-device concurrency behavior on iOS, tvOS, or visionOS.
