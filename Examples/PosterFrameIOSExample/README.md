# PosterFrameKit iOS Example

This focused iOS 16 application verifies PosterFrameKit from a real consumer
target and provides a small manual example. Run it in Xcode and choose a video
from the filtered Photos library; Files remains available as a secondary
source. The app imports Photos assets through a temporary file rather than
loading the full movie into memory, then automatically selects a poster frame
with a 24-candidate budget. It presents progress and failures, followed by the
selected image, actual timestamp, adjusted score, end-to-end duration, and all
six public base metrics. Comparisons, candidate browsing, profiles, and
optional refinements remain in the macOS Demo.

The host's tests import only the public package product, evaluate a synthetic
pixel buffer, generate a short H.264 video with AVFoundation, and run URL-based
poster-frame selection inside an iOS Simulator process. On iOS 18 or newer
they also exercise the optional Vision paths and verify their documented safe
fallback when an analyzer is unavailable in the simulator environment.

Run the shared scheme on any available iPhone Simulator:

```bash
xcodebuild test \
  -project Examples/PosterFrameIOSExample/PosterFrameIOSExample.xcodeproj \
  -scheme PosterFrameIOSExample \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.2'
```

The host deployment target remains iOS 16. A current simulator proves runtime
integration, while the generic iOS build in CI continues to enforce the
package's minimum deployment and availability boundaries at compile time.
Simulator signing is disabled in the project, while physical-device runs use
the development team from the ignored `Config/Signing.local.xcconfig` file.
Create it once by copying `Config/Signing.local.xcconfig.example` and replacing
`YOUR_TEAM_ID`. The setting remains local and does not modify the Xcode project.

The repository's pre-commit hook and CI hygiene check reject hard-coded Apple
development teams. Enable the versioned hook once per clone with:

```bash
git config core.hooksPath .githooks
```
