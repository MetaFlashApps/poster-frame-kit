# PosterFrameKit 0.1.0 Release Checklist

The initial feature set is frozen until the tag. Only reproducible bug fixes,
tests, documentation, and release engineering belong in this release.
Longer-term stable-release criteria remain in [version-1.0.0.md](version-1.0.0.md).

## Before Tagging

- [x] Public API, defaults, optional refinements, and known limits documented
- [x] MIT license and third-party image/fixture attribution present
- [x] No external package dependency or bundled runtime model
- [x] Package, Demo, generated-video tests, and reproducible quality evidence
      recorded in [release validation](release-validation.md)
- [x] README installation and release notes prepared for `0.1.0`
- [x] Static DocC build and GitHub Pages deployment workflow prepared
- [ ] Final clean-history commit passes `Package and Demo` and
      `Apple Platforms and DocC`
- [x] No known critical defect remains

## Publication

1. Publish only the reviewed `main`; keep development archives and bundles
   private. Replacing the existing remote history requires an explicit,
   lease-protected push after local history cleanup.
2. Wait for both checks on that exact commit, then create and push `0.1.0`.
3. Make the repository public and publish the GitHub release.
4. Enable GitHub Pages with **GitHub Actions** as its source, allow release-tag
   deployments in the `github-pages` environment, and publish DocC using the
   [documentation workflow](continuous-integration.md#documentation-publishing).
5. Submit the tagged package to the Swift Package Index.

Branch protection and available GitHub security features are recommended
repository settings, not additional product features or identity-confirmation
gates. Physical tvOS/visionOS validation remains a documented limitation of the
initial release.
