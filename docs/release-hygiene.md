# Release Hygiene Audit

This document records the technical repository-hygiene review performed on
2026-08-27 before the first public tag. It does not replace legal review,
platform CI, or GitHub organization settings.

## Verified in the Current Tree

- The root MIT license, changelog, README, contribution guide, security policy,
  and third-party notices are present.
- No video media is tracked. Benchmark downloads and normalized clips remain in
  ignored directories outside the package source.
- No absolute macOS home-directory or external-volume paths remain in the
  current tracked content.
- A pattern scan found no common cloud tokens, GitHub tokens, OpenAI-style keys,
  or PEM private-key headers in the current tree or reachable local history.
- Ignored build, IDE, Python, benchmark-result, local-environment, credential,
  signing, and media patterns are defined in `.gitignore`.
- Substantial tracked binaries are limited to the Demo application icon, one
  attributed Demo screenshot PNG, and eleven reviewed, fully attributed
  results-gallery JPEGs. No downloaded or normalized benchmark video is
  tracked.
- `Scripts/check-release-hygiene.sh` makes the current-tree checks repeatable and
  rejects tracked video fixtures, local paths, common credential patterns, and
  malformed diffs.
- The reviewed branch is now `main`, `origin/HEAD` points to `origin/main`, and
  the local remote-tracking state contains no additional development branch as
  of 2026-09-06. The local Claude archive remains local and is not part of the
  publication set.

The pattern scan is a focused release check, not a substitute for GitHub secret
scanning or a dedicated credential scanner in CI.

## Owner Actions Before Public Visibility

- Keep the local archive branch private and expose only the reviewed `main`
  branch when repository visibility changes.
- Protect the default branch with both checked-in workflow jobs. Their
  first successful run was owner-confirmed for commit `b2f113e` on 2026-09-06;
  branch protection remains to be verified.
- Enable GitHub private vulnerability reporting so `SECURITY.md` has a direct
  confidential reporting path.
- Enable GitHub secret scanning and push protection when available for the
  organization/repository plan.

## Re-run Before Every Tag

```bash
Scripts/check-release-hygiene.sh
swift test
swift build -c release
```

The checked-in CI matrix adds macOS, iOS, tvOS, and visionOS build gates. The
first remote green run is recorded in
[`release-validation.md`](release-validation.md); default-branch protection
remains an owner action before public visibility.
