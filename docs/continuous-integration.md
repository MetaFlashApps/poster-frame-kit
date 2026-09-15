# Continuous Integration

PosterFrameKit's validation workflow is defined in
`.github/workflows/ci.yml`. It runs for pushes to `main`, pull requests targeting
`main`, and manual dispatches. Feature-branch pushes rely on their pull request,
preventing one update from starting both a push run and a pull-request run.
Repository visibility does not affect the checks; a private repository can
establish the same release baseline before publication.

## Toolchain

The workflow uses GitHub's `macos-26` runner with Xcode 26.3 selected explicitly.
That Xcode release provides Swift 6.2 and the macOS, iOS, tvOS, and visionOS
SDKs required by the package manifest. The workflow logs the actual Xcode and
Swift versions so a future runner-image change is visible rather than silently
changing the release evidence.

The checkout action is pinned to the reviewed commit behind its `v6` tag. Both
jobs receive only read access to repository contents, and checkout credentials
are not retained after source retrieval.

## Required Jobs

`Package and Demo` verifies:

- the release-hygiene policy;
- quality-manifest schema consistency and the fixture fetcher's unit tests;
- the complete package test suite;
- the package release build; and
- the Demo test suite and release build.

`Apple Platforms and DocC` verifies:

- generic macOS, iOS, tvOS, and visionOS package builds without code signing;
- public package integration, synthetic pixel-buffer evaluation, and generated
  H.264 URL selection plus optional Vision paths and their safe fallback inside
  an actual iOS Simulator application process; and
- the macOS DocC archive.

The iOS example app complements rather than replaces the generic iOS build: its
deployment target is iOS 16, while a dynamically selected current iPhone
Simulator proves runtime integration on the hosted image. Generated
AVFoundation integration tests also run on macOS. tvOS and visionOS remain
compile checks; physical-device decoder, accelerator, memory, and lifecycle
behavior remains a release-validation responsibility because hosted testing
cannot establish those properties.

The same app is a focused manual consumer example: select a video from the
filtered Photos library or Files and inspect the generated image, timestamp,
score, elapsed duration, and public metrics. Photos imports remain file-backed
instead of materializing the complete movie in memory. Its project has no
repository-owned development team and disables signing for simulator SDKs, so
local and hosted simulator runs need no signing override. A physical-device run
still requires the developer to select their own team through the ignored
`Signing.local.xcconfig`. The release-hygiene check rejects a hard-coded
development team in committed source, and the versioned pre-commit hook invokes
that same check when enabled through `git config core.hooksPath .githooks`.

Performance and full quality runs are not CI pass/fail gates. Shared hosted
runners do not provide sufficiently stable timing or media-cache conditions
for performance claims, and the freely licensed quality fixtures are too large
for every push. CI still validates the complete downloaded/generated catalog,
its Python tooling, Swift generator metadata, and generated-video integration
tests. Full reports remain explicit release checks.

## Local Equivalent

Run the package job locally with:

```bash
Scripts/check-release-hygiene.sh
python3 Scripts/fetch-benchmark-fixtures.py --check
python3 -m unittest discover -s Scripts/Tests -p 'test_*.py'
swift test
swift build -c release
swift test --package-path Examples/PosterFrameDemo
swift build -c release --package-path Examples/PosterFrameDemo
xcodebuild test \
  -project Examples/PosterFrameIOSExample/PosterFrameIOSExample.xcodeproj \
  -scheme PosterFrameIOSExample \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.2'
```

Use the generic `xcodebuild` destinations documented in the workflow for SDKs
installed on the current machine. Substitute any locally available iPhone
Simulator in the example-test destination. A missing optional platform
component is a local Xcode installation limitation, not a passing platform
result.

## Activation and Branch Protection

The workflow is active on GitHub. Its first successful run of both required
jobs was owner-confirmed for commit `b2f113e` on 2026-09-06 and is recorded in
the [release-validation log](release-validation.md). Before making the
repository public:

1. require `Package and Demo` and `Apple Platforms and DocC` on the protected
   default branch; and
2. keep pull-request workflows on `pull_request`, never
   `pull_request_target`, so untrusted changes do not receive elevated context.

A repository-wide strict `swift format` gate is intentionally not claimed yet.
The current framework and Demo/benchmark trees use different established
indentation styles, so enabling the default formatter today would create a
large unrelated rewrite. A formatting configuration and one mechanical
baseline change should be reviewed separately before making that check
required.

## Documentation Publishing

`.github/workflows/documentation.yml` builds the DocC site from a published
GitHub release's tag. It can also be dispatched manually on `main`. It does
not deploy pull requests or run on every push; normal CI only validates the
static build. The workflow uses pinned official Pages actions, read-only
source checkout, and a separate deployment job with `pages: write` and
`id-token: write` permissions. No Swift package plugin or external package
dependency is needed.

Before the first deployment:

1. In repository **Settings > Pages**, select **GitHub Actions** as the source.
2. In **Settings > Environments > github-pages**, allow the release tags used
   for publication in addition to `main`, if deployment restrictions are set.
3. Publish the GitHub release, or dispatch **Publish Documentation** on `main`.

The expected project-site URL is
[PosterFrameKit API reference](https://metaflashapps.github.io/poster-frame-kit/documentation/posterframekit/).
The workflow reads Pages' actual hosting base path, so a custom-domain setup
does not silently inherit the project-site prefix. Publication is complete
only after the deployment job succeeds; adding the workflow alone does not
make the website live. See GitHub's
[custom Pages workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

To build the project-site artifact locally:

```bash
Scripts/build-documentation.sh
```

The ignored `.build/documentation-site` directory contains the complete static
artifact; DocC warnings fail the build. For a root-hosted local preview:

```bash
Scripts/build-documentation.sh ""
python3 -m http.server 8000 --bind 127.0.0.1 --directory .build/documentation-site
```

Open `http://localhost:8000/documentation/posterframekit/`. The build script
reuses the generated Xcode build directory and writes no generated HTML or
symbol graphs into tracked documentation.
